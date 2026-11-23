# 002: Use three layered Terraform stacks for cluster configuration

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-10-26 |
| **Related** | [Issue #561: migrate k8s configuration to Terraform](https://github.com/omelette-gay/gitops/issues/561) |

## Context

The cluster's Kubernetes-level configuration (everything above the host OS and k3s itself) is managed by Ansible roles
run from `plays/configure-hosts.yml`. This works, but Ansible is a poor fit for managing declarative Kubernetes
resources: it has no state tracking, no drift detection, and changes require running the entire playbook. Terraform is
the better tool for this.

The Ansible roles have circular dependencies between core services. For example, Longhorn needs ServiceMonitor CRDs
from kube-prometheus-stack, but kube-prometheus-stack needs Longhorn for its PVCs. Vault needs Longhorn and
cert-manager, but cert-manager's Vault ClusterIssuer needs Vault. Keycloak needs Vault for backup credentials, but
Vault's Keycloak login needs Keycloak. Ansible resolves this with a `bootstrap` variable: a first pass installs
everything in a minimal configuration, and a second pass completes the setup.

Terraform has two constraints that prevent putting everything in a single root module:

1. **Providers initialise at plan time.** The `vault` and `keycloak` providers need their services running, and
   reachable at their public hostnames, before `terraform plan` can run. If Vault and Keycloak are installed by the
   same root module that configures them through their providers, the first plan fails.
2. **`kubernetes_manifest` validates CRDs at plan time.** If an operator (like the External Secrets Operator) and the
   custom resources it provides (like `SecretStore` and `ExternalSecret`) are created by the same root module using
   `kubernetes_manifest`, the first plan fails because the CRDs don't exist yet. `depends_on` doesn't help, because
   Terraform plans every resource before applying any
   ([hashicorp/terraform-provider-kubernetes#1782](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782)).
   This doesn't apply to custom resources created inside a `helm_release`, as Helm only renders and applies them at
   apply time.

There is already a Terraform root module in `coven/`, with its state in the `coven-tfstate` GCS bucket. It manages a
mix of cloud resources (the GCP project, the state and backup buckets, the backup service account, the cluster token
secret, GitHub Actions workload identity, billing alerts and Hetzner DNS) and cluster resources (GlitchTip, Minecraft
and Trivy). Some of its resources must exist before the cluster does: Ansible reads the cluster token from Secret
Manager, and every stack's state is in the state bucket.

We also need the testlab to mirror production, with different variable values.

## Decision

Replace the Ansible cluster-level configuration, and the existing `coven/` root module, with three Terraform root
modules ("stacks") per environment, applied in order: **bootstrap**, then **platform**, then **apps**. Each has its
own state. This is the "layered stacks" pattern that tools such as Terragrunt and HCP Terraform Stacks automate; we
orchestrate it ourselves with GitHub Actions (see [Orchestration](#orchestration)).

### Boundary rules

1. **Put each resource in the earliest stack that has everything it needs, and no earlier.**
2. If a Terraform provider needs a service running (and reachable) to initialise, that service goes in an earlier
   stack.
3. If `kubernetes_manifest` resources use CRDs from an operator, that operator goes in an earlier stack. Custom
   resources created inside a `helm_release` are exempt; order them with `depends_on` on the `helm_release`
   resources (not on whole `module` blocks, which delays every data source in the module until apply and causes
   permanent diffs).
4. Anything CI needs in order to run at all (the state bucket, its identity in GCP) goes in bootstrap.
5. Platform vs app: "does anything else in the cluster depend on this service?" If yes, platform. If no, app. A failed
   apply stops every later stack, so this rule keeps services nothing depends on from blocking anything else: a bad
   Trivy upgrade must not stop Planka deploying.

### Stack 1: Bootstrap (`bootstrap/`)

Installs operators, CRDs and base services, and the cloud resources everything else relies on. Providers: `helm`,
`kubernetes`, `hcloud`, `random`, and `google` (coven only).

Contains:
- `prometheus-operator-crds` (standalone CRD chart, installed first to break the Longhorn/kube-prometheus-stack cycle)
- Longhorn (with `serviceMonitor.enabled: true`, since the CRDs exist from the previous item)
- kube-prometheus-stack with `crds.enabled: false` (PVCs from Longhorn, alert rules, dashboards, Grafana with static
  OAuth config referencing an optional secret), plus blackbox-exporter and helm-exporter
- Traefik monitoring (`HelmChartConfig` for metrics and the blockpath plugin)
- cert-manager and the Let's Encrypt ClusterIssuer, plus the HTTPS redirect Middleware
- CloudNativePG operator and barman-cloud plugin
- Vault (namespace, metrics-blocking Middleware, Helm release)
- External Secrets Operator
- Keycloak (CNPG database cluster and Helm release only, with no realm or provider-based configuration). On a fresh
  cluster, a sensitive variable sets the password of a temporary first-boot admin, through a Kubernetes Secret that
  Keycloak reads as optional environment variables, so it's only in state while it's needed
- Coven only: the GCP project and APIs, the `coven-tfstate` bucket, GitHub Actions workload identity, billing budget
  alerts, the `coven-backups` bucket and its lifecycle rules, the backup service account (not its key), the
  `k3s-cluster-token` secret, and the `omelette.gay` DNS zone (see [DNS](#dns))

Every custom resource in this stack whose CRD is installed by this stack (the ClusterIssuer, the Keycloak CNPG cluster)
is created through a `helm_release`, never `kubernetes_manifest`.

The `coven-tfstate` bucket and the `omelette.gay` zone have `lifecycle { prevent_destroy = true }`.

### Stack 2: Platform (`platform/`)

Configures the services from bootstrap, and installs platform services that apps depend on. Providers: `helm`,
`kubernetes`, `vault`, `keycloak`, `hcloud`, and `google` (coven only).

Contains:
- Keycloak realm and admin group (via the `keycloak` provider), and the user Terraform itself logs in to Keycloak as,
  whose password is in Vault. A user rather than a confidential client, because a client's secret is always read back
  into state, while a user's password can be set with write-only arguments
- Vault configuration (KV engine, Kubernetes auth, PKI, policies, GitHub JWT auth, Kubernetes credential issuing,
  Keycloak OIDC login)
- cert-manager Vault ClusterIssuer
- Grafana SSO (Keycloak client and Kubernetes secret; Grafana's Helm values in bootstrap already reference the secret
  as optional, so no Helm release update is needed)
- Loki and Alloy (RustFS object store, Helm releases, datasource ConfigMap)
- Coven only: the backup service account key, its 30-day rotation, and writing it into Vault
- Longhorn backup credentials and recurring backup job
- External DNS (Helm release, Vault-synced Hetzner API token, extra DNS records)
- Outbound mail (DKIM key generation, DNS records, Helm release)
- MariaDB operator (needs the Vault ClusterIssuer for webhook certificates)
- GlitchTip
- Discord alerting configuration
- Keycloak backup credentials

### Stack 3: Apps (`apps/`)

Leaf services that consume the platform. Nothing else in the cluster depends on these. Providers: `vault`, `keycloak`,
`kubernetes`, `helm`, `hcloud`.

Each app gets its own `.tf` file that composes the modules it needs (e.g. `app-deployment` for the namespace and Vault
trust, `keycloak-client` for SSO, `vault-k8s-secret` for secrets). This is preferred over a single `for_each` because
apps have different requirements. Everything that belongs to an app lives in its file, including its DNS zone and
records (such as Fastmail's) if it has one, rather than being spread across files by resource type. A domain we own
counts as an app, so a retired domain's file holds its zone, its mail records and its redirect. Only things shared by
several apps, such as the providers and the `omelette.gay` zone, live in shared files.

Contains: per-app GitHub deployment configs, Planka, Minecraft, Factorio, Trivy, decommissioned domain redirects, and,
on coven, the Fastmail and Bluesky DNS records and the zones for domains other than `omelette.gay`.

### Where the existing `coven/` files go

| File | Stack | Notes |
|---|---|---|
| `gcpinit.tf` | bootstrap | |
| `terraformstate.tf` | bootstrap | Holds the state of the stack that creates it, as now |
| `githubactions.tf` | bootstrap | CI needs it to read any stack's state (rule 4) |
| `billing.tf` | bootstrap | Project-level, alongside `gcpinit.tf` |
| `k3s.tf` | bootstrap | Must exist before k3s is installed |
| `backups.tf` | bootstrap and platform | Bucket, lifecycle rules and service account in bootstrap; the key, its rotation and the Vault write in platform, as bootstrap can't use the `vault` provider |
| `domains.tf` | bootstrap and apps | `omelette.gay` in bootstrap; other zones move into the file of the app they belong to |
| `fastmail.tf` | apps | Records in the `omelette.gay` zone, found by name |
| `bsky.tf` | apps | As above |
| GlitchTip | platform | |
| Minecraft | apps | |
| `trivy.tf` | apps | Nothing depends on it (rule 5) |

### DNS

Platform's `vault` and `keycloak` providers connect to `vault.coven.omelette.gay` and `auth.coven.omelette.gay` at plan
time, and their certificates come from Let's Encrypt's HTTP-01 challenge, which needs the names to resolve. external-dns
can't create those records on a brand new zone, because it's installed by platform (its Hetzner token comes from
Vault).

We considered having bootstrap create static records for `vault.coven.omelette.gay`, `auth.coven.omelette.gay` and
`monitoring.coven.omelette.gay`, but decided against it. external-dns manages those records, as it does every ingress's,
and two tools managing the same record would undo each other's changes whenever an ingress changes. The records only go missing if the zone
itself is recreated, as they live in Hetzner rather than in the cluster: rebuilding the cluster keeps them. So in that
case they're added by hand before bootstrap, and replaced by external-dns once platform is up (see
[bootstrapping](../bootstrapping.md)). external-dns manages every record for the cluster's ingresses.

If external-dns is configured with `domainFilters`, adding a zone for a new app also needs a change to platform.

### Layout and state

The content of the bootstrap and platform stacks lives in a shared module. Each environment has a thin root module
that sets the backend, providers and variables, calls the shared module, and holds that environment's extra resources
(on coven, the GCP and DNS resources above). The apps stack has no shared module: which apps run differs between coven
and the testlab, so each environment's `apps/` root module defines its apps directly, using the modules in
`tfmodules/`:

```
tfmodules/
  stack-bootstrap/
  stack-platform/
  keycloak-client/, vault-k8s-secret/, ...   (existing modules)
coven/
  bootstrap/
  platform/
  apps/
testlab/
  bootstrap/
  platform/
  apps/
```

This stops the platform the apps run on drifting apart between coven and the testlab. Each of `coven/bootstrap`,
`coven/platform` and `coven/apps` has its own prefix in `coven-tfstate` (`terraform/bootstrap`, `terraform/platform` and
`terraform/apps`). Every stack starts with empty state, and everything in the existing `coven/` root module (prefix
`terraform/state`) is moved into the stacks explicitly (see [Migration](#migration)). Testlab state stays local and
gitignored.

Each root module has its own `.terraform.lock.hcl`, locked for both `linux_amd64` and `darwin_arm64` (`terraform
providers lock -platform=...`), so lock files made on a Mac work in CI and WSL. Renovate updates all six together.

### Cross-stack data sharing

References between stacks are deterministic (Vault URL, Keycloak URL, namespace names, service addresses, the backup
service account's email, zone names), so shared variable defaults or `.tfvars` files are enough, and data sources can
look things up by name. `terraform_remote_state` isn't needed. If a stack ever needs a value that's only known after
another stack is applied, revisit this.

### Helm releases

Chart versions are hardcoded in `.tf` files, and Renovate updates them directly, replacing the `Chart.yaml` lookup
approach used by Ansible for migrated charts. `prometheus-operator-crds` and kube-prometheus-stack are in the same
Renovate group, so they're always updated in one pull request.

Every `helm_release` sets `atomic = true`, so a failed upgrade is rolled back instead of leaving the release in a
`pending-*` state (which blocks future upgrades and fires `HelmDeployStuck`).

### Orchestration

**CI.** GitHub Actions runs the stacks as separate jobs chained with `needs:` (bootstrap → platform → apps). If a job
fails, the later ones don't run. All jobs share a `concurrency` group with `cancel-in-progress: false`, so two merges
can't apply at the same time. Each job's `timeout-minutes` is longer than the Helm timeouts in that stack, so a job
isn't killed in the middle of a Helm upgrade.

**Pull requests.** Each stack is planned if something it uses has changed: its root module directory, its
`tfmodules/stack-*` module, or any other module under `tfmodules/` (shared modules trigger every stack, as working out
exactly which stacks use them isn't worth the complexity). Each stack is planned against what's currently deployed. So
a change where a later stack depends on something new in an earlier stack (for example, a new operator in bootstrap and
`kubernetes_manifest` resources using its CRDs in platform) must be split into two pull requests, with the earlier
stack's merged and applied first.

**Merges to `main`.** The same rule decides which stacks are applied, still in order.

**Drift detection.** There's no scheduled drift check. Every pull request's plan shows any drift in the stacks it
touches, which we decided was enough: a daily plan of every stack wasn't worth the CI minutes for a cluster this size.

**Ansible.** In the long run, the host configuration workflow and the Terraform workflow are independent. Until the
migration is complete, the cluster-level Ansible play (`plays/configure-cluster.yml`, split out of
`plays/configure-hosts.yml`) runs as a job in the Terraform workflow after the apps stack.

**Credentials.** Provider blocks don't contain credentials; they read them from the environment. In CI, the workflow
logs in to Vault with GitHub JWT auth, and sets environment variables for a short-lived Kubernetes token (for the
`helm` and `kubernetes` providers); the `keycloak` provider reads Terraform's Keycloak user's password from Vault. GCP access
is through workload identity. The same configuration therefore works with other credentials on a fresh cluster.

**Running locally.** A script, `./terraform.sh`, runs `plan` or `apply` for one stack or all three in order, and takes
`--coven` or `--local` like `login.sh` and `bootstrap-auth.sh`. It's how the testlab is run, and is break-glass for
coven: for humans only, not AI agents.

### Building a fresh cluster

Rebuilding the testlab, or rebuilding coven without restoring the datastore:

1. Run the host part of the Ansible playbook, so k3s is installed.
2. Get cluster-admin credentials with `./bootstrap-auth.sh`, and apply bootstrap with `./terraform.sh`.
3. Initialise and unseal Vault, and log in with the root token.
4. Apply platform with `./terraform.sh`, using the root token and Keycloak's temporary admin, whose password is passed
   in the same variable as for bootstrap. Platform creates the GitHub JWT auth that CI uses, the Keycloak realm, and
   Terraform's Keycloak user. (The exact steps are in [bootstrapping](../bootstrapping.md).)
5. Create your own user in the `omelette.gay` realm, add it to the `admins` group, and check you can log in to Vault
   with OIDC. Then revoke the root token and delete Keycloak's temporary admin. (This step stays manual, as it is
   today.)
6. Apply apps. From now on, CI takes over (coven only).

**Starting again from an empty GCP project** (coven only) needs one more step first. The state bucket holds bootstrap's
own state, and bootstrap's `helm` and `kubernetes` providers need k3s running to plan, but Ansible needs the cluster
token secret before it can install k3s. So:

1. Comment out the `backend "gcs"` block in `coven/bootstrap`, and apply only the cloud resources with `-target`
   (the project, the state bucket, workload identity, the backup bucket and service account, the cluster token secret,
   the `omelette.gay` zone).
2. Re-enable the backend and run `terraform init -migrate-state`.
3. Populate `k3s-cluster-token` as described in `docs/bootstrapping.md`, and continue with the steps above.

The cloud resources outlive the cluster, so disaster recovery never needs this.

### Disaster recovery

After the k3s datastore is restored from a snapshot, the cluster can be up to about 6.5 hours behind Terraform state, so
the first plans may show resources to recreate or change. Run all three stacks in order to bring it back in line. This
replaces "re-run the Configure Coven hosts workflow" in step 6 of the rebuild procedure in
`docs/backups-and-recovery.md`.

### What stays in Ansible

Host-level roles run against the machines themselves and stay in Ansible: `omelette.hostbase`,
`omelette.auto-updates`, `omelette.ssh-users`, `omelette.wireguard`, `omelette.k3s-backup`, `omelette.storage` (host
tasks only: iSCSI setup) and `xanmanning.k3s`.

`omelette.kubeconfig` only exists to give Ansible Kubernetes credentials for the cluster-level roles, so it's removed
along with the last of them.

## Migration

### Rehearsal on the testlab

Each stage of the migration is rehearsed on the testlab before it's done on coven, in two ways:

1. **Migrating:** build the testlab as it is today, with Ansible, then migrate the services in that stage exactly as
   planned for coven. Every import must plan with no changes.
2. **Building from scratch:** destroy the testlab and build it with [the fresh-cluster steps](#building-a-fresh-cluster).

Both must pass before the stage is done on coven. The first catches mistakes in the imports; the second catches
missing dependencies between and within stacks, which only show up on an empty cluster.

### Order

Services are migrated bottom-up, in stack order (bootstrap, then platform, then apps), so a Terraform-managed service
never depends on one still in Ansible.

### Each migration pull request

- Adds the service to the right stack, with `import {}` blocks for its existing resources (rather than the `terraform
  import` command), so the import is reviewed and run by CI.
- Removes it from Ansible in the same pull request, so the two never manage the same resources.
- Has a plan showing the imports and **no other changes** to the imported resources before it's merged. If an import
  doesn't plan cleanly, fix the configuration until it does.

Resources moving out of the existing `coven/` root module use a `removed` block with `lifecycle { destroy = false }`
in `coven/` and an `import` block in the new stack, in the same pull request, so nothing is destroyed. CI applies
`coven/` after the three stacks, so nothing is ever unmanaged. Everything in `coven/` moves in the first pull request,
which also creates the stacks. Once that's applied, `coven/` and its state are deleted. Resources that can't be
imported (the backup service account's keys, Minecraft's RCON password) are created fresh in the new stack, and the
old ones destroyed with `removed` blocks with `lifecycle { destroy = true }`.

Importing a resource with a write-only secret (`data_wo` on a Kubernetes Secret, `client_secret_wo` on a Keycloak
client) doesn't record its revision, so the first apply writes the secret again, which would rotate it. To keep the
existing value, copy it into Vault by hand before the import, and pass it into the module through an ephemeral input,
so the same value is written back. Remove the input once the import has been applied. (`moved` blocks only work within one root module; use them for resources that move into the
shared module within the same stack.)

A service with data (Vault, Keycloak's database, anything with Longhorn volumes) must never be migrated by uninstalling
and reinstalling it, as that can delete its volumes.

### Rolling back

Importing a resource doesn't change it, so a migration pull request can be reversed: add `removed` blocks with
`lifecycle { destroy = false }` for the service's resources, and restore its Ansible role.

### When it's done

The migration is complete when:

- the Ansible `localhost` play is empty and removed, along with the `bootstrap` variable
- `omelette.kubeconfig` is removed
- `Chart.yaml` no longer contains any chart that Terraform installs, and the `helm_chart` lookup plugin is removed if
  nothing uses it
- `docs/bootstrapping.md`, `docs/backups-and-recovery.md`, `docs/cluster-overview.md`, `docs/diagnosing-issues.md` and
  the README describe the new process

## Alternatives considered

**Single Terraform root module.** Can't work because of the plan-time constraints above. It would need `terraform apply
-target` on the first run, which is fragile and doesn't suit CI.

**Two stacks (bootstrap + main).** The original proposal. It puts Keycloak's realm configuration in the same stack as
its Helm release, which fails because the `keycloak` provider can't initialise until the release is applied. The same
problem applies to anything both installed and configured through a provider (GlitchTip may be in future). Three stacks
separate installing services, configuring them through their providers, and deploying apps that use them.

**A separate cloud stack.** Keeping the GCP and DNS resources in their own stack, applied before bootstrap, would avoid
the `-target` step when starting from an empty GCP project, and would let cloud changes be applied while the cluster is
down. But it's a fourth stack in coven with no equivalent in the testlab, and the problem it solves only happens if we
start again from nothing, which `-target` handles. Folding the resources into the three stacks by the boundary rules
keeps coven and the testlab the same shape.

**Terragrunt.** Builds the dependency graph between stacks and runs them in order (`terragrunt run --all`), and can
pass outputs between them, with mock outputs for planning before an upstream stack exists. We have three stacks with a
fixed order and no outputs to pass, so `needs:` in GitHub Actions does the same job without another tool to learn and
maintain. Mock outputs also wouldn't help with our main constraint, as a provider that can't connect to Vault fails
whatever inputs it's given. Reconsider if the number of stacks grows a lot or they start needing each other's outputs.

**HCP Terraform Stacks.** HashiCorp's own multi-stack feature, generally available since 2025. It orders components,
triggers downstream stacks when outputs change, and can defer parts of a plan that depend on things that don't exist
yet. But it only runs in HCP Terraform, so our state would move out of GCS, it's billed per resource under management,
and it uses its own configuration language. That's too much change for this cluster.

**Other orchestrators (Spacelift, env0, Terramate).** Offer stack dependencies as a service or tool. Not worth it for
three stacks for the same reasons as Terragrunt.

**`kubectl_manifest` (`alekc/kubectl` provider) instead of `kubernetes_manifest`.** Doesn't validate custom resources
at plan time, so it avoids constraint 2. It doesn't help with constraint 1, so we'd still need the stacks. Since we can
use Helm releases for custom resources instead, it isn't needed now, but it's an option if a custom resource has to be
in the same stack as its operator and can't come from a chart.

**Keep Ansible, fix the bootstrap pattern.** The bootstrap pattern works, but Ansible has no state, no plan and no
drift detection, and every run re-applies everything. Terraform's declarative model suits Kubernetes resources better,
and its plan step catches mistakes before they're applied.

## Consequences

- **More pipeline.** Three `terraform apply` jobs instead of one `ansible-playbook` run and one `terraform apply`. Each
  is smaller and safer, but the workflow and its change detection need maintaining.
- **Some changes need two pull requests**, when a later stack depends on something new in an earlier one.
- **Vault must be unsealed by hand between bootstrap and platform on a fresh cluster.** No cloud KMS is available on
  Hetzner or the testlab for auto-unseal.
- **A sealed Vault stops all three stacks in CI**, including bootstrap, because CI gets its Kubernetes credentials from
  Vault. This is no worse than today, but if a bootstrap change breaks Vault, CI can't fix it: run bootstrap with
  `./terraform.sh` and `bootstrap-auth.sh` credentials. The Vault chart doesn't restart its pod on upgrade, so a Vault
  chart bump applies without sealing Vault; it only seals when the pod is next restarted.
- **Bootstrap needs both GCP and the cluster to plan**, so a GCP outage can block it, and starting again from an empty
  GCP project needs a one-off `-target` apply.
- **Bootstrap owns all foundational Helm releases.** Platform and apps never update them. They only create additional
  resources (secrets, manifests, Vault configuration) that the bootstrap services pick up at runtime, which avoids
  conflicts between stacks.
- **Grafana SSO depends on an optional Kubernetes secret.** Bootstrap's kube-prometheus-stack values include the full
  OAuth configuration with a fixed client ID and URLs, and reference `grafana-keycloak-creds` through `envFromSecrets`
  with `optional: true`. SSO doesn't work until platform creates the client and secret, but Grafana doesn't crash.
- **Recreating the `omelette.gay` zone needs three records added by hand** (for Vault, Keycloak and Grafana) before
  bootstrap, until external-dns takes them over.
- **`prometheus-operator-crds` must stay in step with kube-prometheus-stack**, which the Renovate group handles. The
  CRDs must never be older than the chart that uses them.
- **Terraform state contains secrets**, such as Keycloak client secrets, and Keycloak's temporary admin password while
  it exists. This was already true of `coven/`, and the `coven-tfstate` bucket is treated as sensitive.
  Where the providers support write-only arguments, use them so secrets written to Vault aren't stored in state. We aim
  to keep as few secrets in state as possible (see [secrets](../secrets.md#secrets-and-terraform-state)). Write-only
  arguments don't stop a provider reading a value back after writing it, so Keycloak client secrets and the contents of
  any `kubernetes_secret_v1` still end up in state, whereas a secret written to Vault with a write-only argument and
  synced to Kubernetes by External Secrets Operator doesn't.
- **A cancelled or timed-out run can leave the state locked**, needing `terraform force-unlock`. Add this to
  `docs/diagnosing-issues.md`.
- **Migrating needs care**: imports must plan cleanly, and stateful services must never be reinstalled.
- **The testlab mirrors the stack structure** with different variable values (local domains, insecure TLS, dummy API
  tokens, no GCP resources), and is run with the same script used for break-glass on coven.
- When this is accepted, update the [ADR index](./README.md) and the Ansible vs Terraform table in the
  [cluster overview](../cluster-overview.md).
