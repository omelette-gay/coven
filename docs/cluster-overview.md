# Cluster Overview

This document describes how our k3s cluster ("coven") is built and configured. It is written primarily so that an AI
agent diagnosing alerts or errors on the cluster has the context it needs, but should be just as useful to humans.
For the practical "how do I start investigating" guide, see [diagnosing issues](./diagnosing-issues.md).

## Key principles

- **Everything is infrastructure as code.** The source of truth for the cluster is this repo (and, for some apps, the
  app's own repo). Manual changes made with `kubectl edit`/`kubectl apply`/`helm upgrade` or by hand on the hosts will
  either be reverted on the next run of Ansible/Terraform, or cause drift that breaks the next run. A fix is only
  really a fix once it is in code.
- **Changes are deployed by GitHub Actions on merge to `main`.** The host playbook and `terraform apply` run
  automatically on every push to `main` (see [.github/workflows/](../.github/workflows/)). Terraform also runs a plan on
  every pull request. So "what changed recently?" can usually be answered with `git log` on this repo. Only `main`'s
  workflows get credentials, and some plans wait for approval: see [CI and its credentials](#ci-and-its-credentials).
- **Dependency versions are bumped automatically by Renovate.** Helm chart versions are pinned in the `helm_release`
  resources in the `.tf` files, and Terraform provider versions in the lock files. Renovate PRs are merged frequently, so
  a recent chart upgrade is a common cause of new alerts.
- **Secrets live in Vault, never in the repo.** See [secrets](./secrets.md).
- **New features go to the testlab first.** We prefer to develop new features on the Vagrant testlab before
  deploying them to coven. Bug fixes can go straight to coven. See [Testlab](#testlab).
- **Significant decisions are recorded as ADRs** in [adr/](./adr/README.md), which say why things are the way they are.
  Check there before reversing a deliberate choice, and add one for any new decision that's hard to undo.
- **Incidents are written up** in the [incident log](./incidents/README.md), one file per incident.

## Ansible vs Terraform

Ansible configures the hosts, and Terraform everything on the cluster (see
[ADR 002](./adr/002-three-stack-terraform-for-cluster-configuration.md)):

| Layer                                  | Tool          | Where                                                                  |
|----------------------------------------|---------------|------------------------------------------------------------------------|
| Host OS configuration                  | Ansible       | [plays/configure-hosts.yml](../plays/configure-hosts.yml)              |
| k3s installation                       | Ansible       | `xanmanning.k3s` role (external, see [requirements.yml](../requirements.yml)) |
| Operators and base services (Longhorn, monitoring, cert-manager, CNPG, Vault, ESO, Keycloak) | Terraform | `coven/bootstrap/`, using [tfmodules/stack-bootstrap/](../tfmodules/stack-bootstrap/) |
| Vault and Keycloak configuration, and services apps depend on | Terraform | `coven/platform/`, using [tfmodules/stack-platform/](../tfmodules/stack-platform/) |
| Apps                                   | Terraform     | `coven/apps/`, using modules in [tfmodules/](../tfmodules/)            |
| GCP project, DNS zones, cloud resources | Terraform    | Mostly `coven/bootstrap/`; DNS records for apps in `coven/apps/`        |
| Self-deploying apps                    | The app's own repo, and Terraform | GitHub Actions in each app repo, deploying with Helm into its own namespace. Its namespace, Vault access, secrets and SSO client are in `coven/apps/` |

When working out how to fix something, first find out which of these owns it, as that tells you where the change
needs to be made.

### What Ansible manages

Everything runs against the nodes themselves, as root:

- `omelette.hostbase` - hostname, timezone (UTC) and the EPEL repository
- `omelette.auto-updates` - `dnf-automatic` applying OS updates automatically, plus a textfile exporter that reports
  when a reboot is needed (feeds the `NodeNeedsRestarting` alert)
- `omelette.ssh-users` - SSH users and keys (the `ssh_users` group var)
- `omelette.wireguard` - the WireGuard tunnel from strix to the home network (see [Networking](#networking)), plus a
  textfile exporter for handshake metrics
- `omelette.k3s-backup` - a systemd timer snapshotting the k3s datastore to GCS every 6 hours, and restoring it if it's
  missing (controller only)
- `xanmanning.k3s` - installs and configures k3s
- `omelette.storage` - iSCSI tools needed by Longhorn

### What Terraform manages

Terraform state is stored in the `coven-tfstate` GCS bucket. The `coven/` folder is production; `testlab/` is the
local Vagrant VM. Each environment has three stacks, each with its own state, applied in order (see
[ADR 002](./adr/002-three-stack-terraform-for-cluster-configuration.md) for what goes where):

- `bootstrap/` - operators, CRDs and base services, and on coven the cloud resources everything else needs. It can't
  use Vault, so on coven it reads the Hetzner token from `HCLOUD_TOKEN`.
- `platform/` - configures Vault and Keycloak, and runs services that apps depend on.
- `apps/` - leaf services that nothing else in the cluster depends on.

The bootstrap and platform stacks are shared modules (`tfmodules/stack-bootstrap/` and `tfmodules/stack-platform/`),
so both environments run the same platform. Each service in them is its own module in `tfmodules/` (e.g.
`tfmodules/keycloak/`, `tfmodules/logging/`); see each stack's README. Apps differ between environments, so each environment's `apps/` defines
them directly.

Between them, they manage:

- Bootstrap: Longhorn (`longhorn-system`, the default storage class), the Prometheus Operator CRDs, kube-prometheus-stack
  with its alert rules, the blackbox exporter and helm-exporter (`monitoring`), Traefik's metrics config,
  cert-manager and the Let's Encrypt issuer, the HTTPS redirect middleware, the CloudNativePG operator, barman-cloud
  plugin and PostgreSQL image catalog (`cnpg-system`), Vault (`vault`), External Secrets Operator (`external-secrets`), and Keycloak and its
  Postgres cluster (`keycloak`)
- Platform: Vault's auth methods, policies, secrets engines and CA, and cert-manager's Vault issuer; the `omelette.gay`
  realm, its `admins` group and Terraform's own Keycloak user; Grafana's SSO client and Discord alerting; Loki (with a
  RustFS object store) and Alloy; Longhorn's backup credentials and its nightly backup and daily snapshot jobs;
  external-dns (`external-dns`), and on coven the machines' DNS records; Postfix for outbound mail (`mail`), with its DKIM key and DNS
  records; the MariaDB operator (`mariadb-system`)

- GCP project resources: APIs, the `coven-tfstate` bucket (which keeps old versions of each stack's state for 30 days,
  as state holds secrets), the `coven-backups` bucket (with a 14-day expiry on objects under `k3s/` only) and backup
  service account (with keys rotated every 30
  days and written into Vault), the `k3s-cluster-token` secret, the workload identity pools for GitHub Actions and for the
  cluster's service accounts (applied by a project owner, as CI can only read them), billing budget alerts
- Hetzner DNS zones and static records (Fastmail, Bluesky and GitHub verification, GitHub Pages CNAMEs)
- `glitchtip` namespace - GlitchTip error tracking (errors.omelette.gay)
- `vikunja` namespace - Vikunja task lists and kanban boards (tasks.omelette.gay), with its Postgres cluster, a
  RustFS object store for attachments, and agentgateway in front of its MCP server for OAuth (see ADR 008)
- `minecraft-<server_id>` namespaces - Minecraft servers
- `factorio-<server_id>` namespaces - Factorio servers
- A namespace per self-deploying app, with Vault access for its GitHub repo, and any secrets and Keycloak client it needs
- `luna-multiplayer` namespace - Luna Multiplayer (Kerbal Space Program) servers, installed from the Helm chart published
  by [luna-multiplayer-helm-chart](https://github.com/omelette-gay/luna-multiplayer-helm-chart). Renovate bumps the
  chart version in `tfmodules/luna-multiplayer/main.tf`
- `trivy-system` namespace - Trivy Operator vulnerability scanning
- A namespace per retired domain (e.g. `cjn-me-uk`) - redirects to the domain that replaced it

### Self-deploying apps

Apps with a file in [coven/apps/](../coven/apps/) that uses the `app-namespace` and `github-deployment-role` modules
(e.g. `wedding`, `home-assistant`, `weight-tracker`, `pling-org-uk`, `chrisn-xyz`) deploy themselves from their own
GitHub repos, using Vault to obtain credentials scoped to their namespace. This repo only sets up the namespace's
access, secrets and SSO client. If an alert is for one of those namespaces, the workload itself is defined in the app's
repo, whose name is in that file as `github_repo`, not here. See [deploying apps](./deploying-apps.md).

### Things k3s provides itself

k3s ships with some components that are not deployed by us directly: Traefik (ingress, in `kube-system`), CoreDNS,
metrics-server, ServiceLB (`svclb-*` pods) and the local-path provisioner. We customise Traefik through a
`HelmChartConfig` in the bootstrap stack (enabling metrics, the dashboard and a plugin, and running it where ServiceLB
runs so it sees clients' real IP addresses: see [Nodes](#nodes)). Longhorn is made the default storage class instead of
local-path.

## Nodes

The cluster has two nodes, both with swap disabled:

| Node     | Kubernetes node name        | Role                      | OS              | Location                                                       | Label `coven.omelette.gay/location` |
|----------|-----------------------------|---------------------------|-----------------|----------------------------------------------------------------|-------------------------------------|
| strix    | `strix.xdc.omelette.gay`    | Controller (k3s server)   | Rocky Linux 9   | Hetzner dedicated server, FSN1-DC15 datacentre, Germany (RAID-1) | `xdc`                               |
| grimhilde | `grimhilde.gs.omelette.gay` | Worker (k3s agent)       | Rocky Linux 10  | Chris's old Mac Mini on the home network      | `gs`                                |

grimhilde runs Rocky Linux 10 because Rocky 9 wouldn't install on its hardware. The nodes are on different OS major
versions, so the kernel, package versions and some host tooling differ between them. Keep this in mind for problems
that only affect one node, or that started after an OS update on one node.

- There is **only one controller**, so the control plane is a single point of failure. If strix is down, the
  Kubernetes API is down.
- The controller is not tainted, so it runs normal workloads as well as the control plane. Pods can be scheduled
  on either node unless they have a node selector or affinity.
- The k3s datastore is **SQLite** (`/var/lib/rancher/k3s/server/db/state.db`), not etcd. A snapshot of it is uploaded
  to `gs://coven-backups/k3s/strix/` every 6 hours by the `k3s-datastore-backup` systemd timer on strix. See
  [backups and recovery](./backups-and-recovery.md#k3s-control-plane--sqlite-state).
- kine, k3s's SQLite layer, writes to the datastore constantly (mostly lease renewals), so anything that holds the
  database open or locks it for long will stall the API server's writes. When that happens, controllers that use
  leader election (CNPG, barman-cloud, the Longhorn CSI sidecars) fail to renew their leases and restart, on both
  nodes, and k3s logs `Slow SQL` warnings.
- Only strix has `svccontroller.k3s.cattle.io/enablelb=true`, so **all external traffic enters through strix**
  (public IPs 168.119.4.112 and 2a01:4f8:242:4f21::2), including traffic for pods running on grimhilde.
- **Traefik runs on strix too**, pinned to nodes with the same label. Its Service uses `externalTrafficPolicy: Local`,
  so kube-proxy doesn't rewrite the client's address on the way in, and apps see real IP addresses in
  `X-Forwarded-For` (with `Cluster`, they saw a 10.42 address). `Local` only sends traffic to a Traefik pod on the node
  it arrived at, which is why Traefik has to be where ServiceLB is. While strix is drained or rebooting, Traefik has
  nowhere to run, so public sites are down until strix is uncordoned. Traefik has no PodDisruptionBudget, so it doesn't
  block the drain.
- Workloads that must use a datacentre IP (e.g. outbound mail, the Minecraft and Factorio servers) are pinned or prefer
  `coven.omelette.gay/location=xdc`.
- See [names and numbers](./names-and-numbers.md) for naming conventions and IP ranges.

The inventory for these hosts is in [coven/inventory/](../coven/inventory/).

## Networking

- The two nodes are in different locations, connected over the internet. strix runs a WireGuard interface (`wg0`)
  which connects to the home router (janus, `janus.gs.omelette.gay:59384`), giving strix the address
  192.168.178.203 on the home LAN (192.168.178.0/24). grimhilde is on that LAN directly at 192.168.178.36.
- strix's k3s `node-ip` is its WireGuard address, and **flannel (pod networking) runs over `wg0`**. This means all
  node-to-node traffic, including Longhorn replication and pod-to-pod traffic, goes over the tunnel and the home
  internet connection.
- The tunnel uses an MTU of 1392 and TCP MSS clamping (to 1220) on strix's public interface, which were added to fix
  connectivity problems in the cluster.
- If the tunnel, the home internet connection or janus goes down, grimhilde will become `NotReady`, and anything
  running there will be unreachable. Expect `WireguardPeerDown`, `LonghornNodeDown`, degraded Longhorn volumes and
  failing HTTP probes to fire together in that case.

### How people and automation reach the nodes

grimhilde has no public address, so how you reach it depends on where you are:

| From                      | strix                                   | grimhilde                                                       |
|---------------------------|-----------------------------------------|-----------------------------------------------------------------|
| The home network (where we normally work from) | `strix.xdc.omelette.gay` over the internet | Directly on the LAN at 192.168.178.36 (`grimhilde.gs.omelette.gay`) |
| GitHub Actions            | Over the internet                       | Through a WireGuard tunnel to janus, which the workflow brings up |
| Anywhere else             | Over the internet                       | Not directly reachable; jump through strix, which is on the home LAN via its own tunnel |

The Ansible job (in [.github/workflows/configure-hosts.yml](../.github/workflows/configure-hosts.yml)) brings up its own
WireGuard peer (192.168.178.204) to janus before running the playbook, so it can reach grimhilde, and takes it down
again afterwards. A concurrency group stops two runs using the peer at once. If that tunnel can't be established (for
example because janus or the home internet connection is down), it will fail. The Terraform jobs
only talk to the Kubernetes API on strix, Vault and cloud APIs, so they don't need the tunnel.

## Platform services

| Concern              | What we use                                                                                     |
|----------------------|--------------------------------------------------------------------------------------------------|
| Ingress / reverse proxy | Traefik (k3s built-in). See [HTTPS](./https.md)                                              |
| TLS certificates     | cert-manager, `letsencrypt` ClusterIssuer (prod), `vault` issuer for the testlab                  |
| DNS                  | Hetzner DNS; zones in Terraform, records from Ingresses created by external-dns                 |
| Block storage        | Longhorn, 2 replicas by default (one per node), best-effort data locality, replica timeout increased to 30s because replication goes over the internet, snapshots checksummed on creation (fast-check) and fast replica rebuild enabled |
| Object storage       | RustFS (S3-compatible), for Loki, GlitchTip and Vikunja. Each store sends metrics to Prometheus over OTLP |
| PostgreSQL           | CloudNativePG clusters, backed up to GCS via barman-cloud                                       |
| MySQL                | MariaDB operator, physical backups to GCS                                                       |
| Secrets              | Vault (manual unseal, no auto-unseal), synced into k8s by External Secrets Operator             |
| SSO                  | Keycloak, realm `omelette.gay` for users, `master` for admin                                     |
| Outbound email       | Postfix relay at `mail.mail.svc.cluster.local:587`                                               |
| Metrics & alerting   | kube-prometheus-stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics)     |
| Logs                 | Loki (single binary) with Alloy collecting pod logs, systemd journals and Kubernetes events      |
| HTTP uptime checks   | Prometheus blackbox exporter, configured with `Probe` resources                                 |
| App error tracking   | GlitchTip (errors.omelette.gay)                                                                  |
| Vulnerability scanning | Trivy Operator                                                                                |
| Backups              | Everything goes to the `coven-backups` GCS bucket (europe-west2). See [backups and recovery](./backups-and-recovery.md) |

## Access and authentication

- **kubectl, normally**: run `./login.sh --coven`. This logs in to Vault via Keycloak SSO and gets a short-lived
  Kubernetes service account token from Vault. **It only works while Vault is unsealed and Keycloak is up.**
  The login is **interactive**: `vault login -method=oidc` opens a browser window where a human signs in to Keycloak,
  and the script waits until they have. An AI agent can't complete this itself, so a human has to run `login.sh`.
  Once they have, the token is saved in the `coven` kubeconfig context and the agent can use `kubectl` and `helm`
  as normal. When the token expires, `kubectl` fails with `Unauthorized`. The agent should then ask a human to run
  `login.sh` again, and not switch to `bootstrap-auth.sh`.
- **kubectl, when Vault or Keycloak is down**: run `./bootstrap-auth.sh --coven`. It SSHes to strix and copies the
  k3s admin client certificate from `/etc/rancher/k3s/k3s.yaml` into your local kubeconfig, so it doesn't need Vault.
  These credentials are full cluster-admin and long-lived, so only use them when `login.sh` won't work, and switch
  back to `login.sh` once Vault is available. You can also SSH to strix and run `sudo k3s kubectl ...` there.
- **SSH**: users in the `ssh_users` group var can SSH to the hosts and have passwordless sudo. See
  [How people and automation reach the nodes](#how-people-and-automation-reach-the-nodes) for which host is
  reachable from where.
- **Grafana**: https://monitoring.coven.omelette.gay, SSO-only (the login form is disabled).
- **Vault UI**: https://vault.coven.omelette.gay (see the README for how to log in).
- **Prometheus, Alertmanager, Loki, the Traefik dashboard and the Longhorn UI are not exposed to the internet** -
  use `kubectl port-forward` to reach them.

## CI and its credentials

CI is admin over the cluster, Vault and GCP: a Terraform plan has to read secrets that lead back to admin, so even a
plan is effectively admin, and so is approving one. So credentials are gated on which workflow is running, not just
which repository ([ADR 006](./adr/006-gate-ci-credentials-by-workflow-and-environment.md)).

**Only `main`'s copy of three reusable workflows gets credentials.** The workflows that run on events call them at
`@main`:

| Reusable workflow | Environment | Vault roles | Called by |
|---|---|---|---|
| [tfplan-stack.yml](../.github/workflows/tfplan-stack.yml) | `coven-plan` or `coven-plan-review` | `coven-tfplan`, `github-coven-tfplan` | `tfplan.yml`, on pull requests |
| [tfapply-stack.yml](../.github/workflows/tfapply-stack.yml) | `coven` | `coven-tfapply`, `github-coven-tfapply` | `tfapply.yml`, on push to `main` |
| [configure-hosts.yml](../.github/workflows/configure-hosts.yml) | `coven` | `coven-configure-hosts` | `host_config.yml`, on push to `main` |

- **The Vault roles and GCP principals are bound on three claims** that GitHub puts in the job's OIDC token, which no
  workflow can change: `repository_id` (coven's ID, so a new repository with the same name gets nothing),
  `job_workflow_ref` (`omelette-gay/coven/.github/workflows/<file>@refs/heads/main`) and `environment`. The Vault roles
  are in [tfmodules/stack-platform/vault.tf](../tfmodules/stack-platform/vault.tf) and
  [coven/platform/githubactions.tf](../coven/platform/githubactions.tf). The GCP principals use their own provider,
  `coven-github-actions`, in [coven/bootstrap/githubactions.tf](../coven/bootstrap/githubactions.tf).
- **A pull request can't get credentials by editing the workflows.** Calling its own copy of a reusable workflow, a
  branch's or a tag's, copying the steps into the caller, or adding a new workflow that asks for an environment all
  give a different `job_workflow_ref` or no `environment`, so Vault and GCP refuse them. The ruleset on `main` makes
  sure code only gets there through a merged pull request.
- **A pull request can change what runs with the credentials.** The reusable workflows only check out the code and
  call a composite action in [.github/actions/](../.github/actions/), which runs from the pull request's checkout, as
  does the Terraform code. So pull requests test the composite actions, but changes to the reusable workflows
  themselves only run once they're merged.
- **GCP:** the plan and apply principals get `roles/editor`, the k3s token, read-only access to the workload identity
  pools and the roles in apps' own projects. The host playbook only gets the k3s token. CI can't change either pool, so
  it can't loosen its own conditions: both pools are applied by a project owner from their own machine, and CI's apply
  then finds nothing to change.

### The environments

The environments and rulesets are configured in GitHub, not in code.
[working-in-public.md](./working-in-public.md#repository-settings) has the exact settings and how to check them.

| Environment | Rules | Used by |
|---|---|---|
| `coven` | Only `main`. Holds the WireGuard and SSH secrets | apply and the host playbook |
| `coven-plan` | No reviewers | plans of pull requests from this repository, opened and triggered by Chris or Meg |
| `coven-plan-review` | Chris or Meg must approve, and admins can't bypass it | every other plan, including Renovate's |

`tfplan-stack.yml` chooses between the plan environments from the event, never from inputs: it's `coven-plan` only for
a `pull_request` event whose head repository is this one, and where both the pull request's author and the user who
triggered the run (`github.actor_id`) are Chris (462992) or Meg (116823812). Anything else, such as a Renovate pull
request, a push to someone else's pull request, or a re-run of a Renovate run, waits for approval.

### Approving plans

**Approving a plan gives admin to the code in that pull request**, and admin can make itself permanent (new Vault
tokens, Kubernetes service account tokens, GCP service account keys). A bad approval means rotating Vault,
Kubernetes, GCP, Hetzner and Keycloak credentials. Most of these are Renovate's: about one per weekly bundle, plus
separate updates and rebases. Before approving, from the run's page (**Review deployments**):

- Read the whole diff, not just the description. For a rebase, check what changed since the last plan you approved.
- Look hardest at anything that runs code in CI: provider and module versions and lock files, chart versions,
  action versions and anything in `.github/`, `data "external"` and other scripts.
- If anything's unexpected, reject it. A rejected plan changes nothing.

### Plan output

Plans are public, as they're posted on pull requests. The plan job writes the plan to a file rather than the log, and
scans it with a pinned gitleaks. If gitleaks finds anything, only the changed resource addresses and actions are posted,
and the job fails: look at the plan locally (`./terraform.sh --coven plan <stack>`) to see what it found. A separate job
with no cloud credentials posts the comment and the job summary, treating the plan as untrusted text.

### Checking the gate

The rulesets and environments are repository settings, not code, so if one is changed the gate quietly goes. Check
them after changing settings, and now and then:

```bash
gh api repos/omelette-gay/coven/rulesets --jq '.[] | {name, target, enforcement}'
gh api repos/omelette-gay/coven/environments --jq '.environments[] | {name, protection_rules, deployment_branch_policy, can_admins_bypass}'
gh api repos/omelette-gay/coven/environments/coven/deployment-branch-policies --jq '.branch_policies[].name'
```

Expect: a `main` branch ruleset with pull requests only and no bypass actors, and a tag ruleset blocking `main`; `coven`
limited to `main`; `coven-plan-review` with Chris and Meg as required reviewers and `can_admins_bypass` false. Fork pull
requests from outside contributors must also need approval to run (Settings → Actions → General).

## Alerting

- Alert rules are Prometheus rules. Our own rules are defined in `additionalPrometheusRulesMap` in
  [tfmodules/kube-prometheus-stack/values/alerts/](../tfmodules/kube-prometheus-stack/values/alerts/) (one file per group);
  others come with the kube-prometheus-stack defaults and with charts that ship their own `PrometheusRule`s (e.g.
  Loki). Prometheus picks up `ServiceMonitor`, `PodMonitor`, `Probe` and `PrometheusRule` resources from every
  namespace.
- Alertmanager sends all alerts to Discord, grouped by `namespace` and `alertname`, with a repeat interval of 7 days.
  Grafana-managed alerts also go to the same Discord channel.
- Host-level metrics that aren't available from a normal exporter are written by systemd timers into
  `/run/node-exporter/*.prom` on each host and read by node-exporter's textfile collector (`node_reboot_required`,
  `wireguard_*`, `k3s_datastore_backup_*`).

## Maintenance that happens automatically

These are worth knowing about as they can explain alerts and restarts:

- **OS updates** are applied automatically by `dnf-automatic`. Nodes are not rebooted automatically; when one needs
  rebooting, `NodeNeedsRestarting` fires and a human runs [plays/rolling-reboot.yml](../plays/rolling-reboot.yml)
  (which switches over CNPG primaries, drains, reboots and uncordons each node in turn).
- **Longhorn backups** of labelled volumes run at 07:30 and 19:30 UTC, keeping 14.
- **Longhorn snapshots** of every volume that has no recurring job of its own (Longhorn's `default` group) are
  taken by the `daily-snapshot` job at 03:00 UTC, keeping 2. This is so that replica rebuilds after a node reboot
  only copy what's changed since the last checksummed snapshot over the WireGuard tunnel, rather than the whole
  volume. Backed-up volumes already get a snapshot with each backup.
- **CNPG and MariaDB backups** run on per-database schedules defined in their Helm values.
- **PostgreSQL image updates** arrive in the weekly Platform Renovate PR as a new commit of the CNPG image catalog
  (see [ADR 009](./adr/009-take-postgres-images-from-a-shared-image-catalog.md)). Once merged, the operator rolls every
  database whose image changed, five minutes apart, with a switchover each, so expect brief primary changes and
  restarts across all the Postgres clusters.
- **k3s datastore snapshots** are taken on strix every 6 hours (00:00, 06:00, 12:00 and 18:00 UTC, plus up to 30
  minutes of random delay), and kept for 14 days.
- **Backup service account keys** are rotated every 30 days by Terraform, which rewrites the secrets in Vault; the
  External Secrets Operator then syncs them into k8s.
- **Renovate** raises PRs for new chart, provider and Ansible collection versions; once merged these deploy
  straight away.

## Testlab

There is also a single-node Vagrant VM ("testlab", inventory in [testlab/](../testlab/)) used to test changes. It
uses `coven.local` hostnames, Vault-issued certificates instead of Let's Encrypt, and local Terraform state. Alerts
come from production (coven) unless stated otherwise.

**New features should be built and tested in the testlab first**, before they go to coven. This covers things like
new services, new Terraform modules and changes to Ansible roles. Bug fixes for
problems on coven don't need to go through the testlab first. When suggesting a fix while diagnosing an issue,
treat it as a bug fix; if the fix needs something new to be built, say that it should be tried in the testlab first.
See the [README](../README.md#testlab) for how to set up the testlab.
