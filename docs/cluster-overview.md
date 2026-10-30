# Cluster Overview

This document describes how our k3s cluster ("coven") is built and configured. It is written primarily so that an AI
agent diagnosing alerts or errors on the cluster has the context it needs, but should be just as useful to humans.
For the practical "how do I start investigating" guide, see [diagnosing issues](./diagnosing-issues.md).

## Key principles

- **Everything is infrastructure as code.** The source of truth for the cluster is this repo (and, for some apps, the
  app's own repo). Manual changes made with `kubectl edit`/`kubectl apply`/`helm upgrade` or by hand on the hosts will
  either be reverted on the next run of Ansible/Terraform, or cause drift that breaks the next run. A fix is only
  really a fix once it is in code.
- **Changes are deployed by GitHub Actions on merge to `main`.** The Ansible playbooks and `terraform apply` run
  automatically on every push to `main` (see [.github/workflows/](../.github/workflows/)). Terraform also runs a plan on
  every pull request. So "what changed recently?" can usually be answered with `git log` on this repo.
- **Dependency versions are bumped automatically by Renovate.** Helm chart versions are pinned in
  [Chart.yaml](../Chart.yaml) (which is not a real chart, it only exists so Renovate can update it), and Ansible reads
  them from there via the `helm_chart` lookup plugin. Terraform provider and module chart versions are pinned in the
  `.tf` files. Renovate PRs are merged frequently, so a recent chart upgrade is a common cause of new alerts.
- **Secrets live in Vault, never in the repo.** See [secrets](./secrets.md).
- **New features go to the testlab first.** We prefer to develop new features on the Vagrant testlab before
  deploying them to coven. Bug fixes can go straight to coven. See [Testlab](#testlab).
- **Significant decisions are recorded as ADRs** in [adr/](./adr/README.md), which say why things are the way they are.
  Check there before reversing a deliberate choice, and add one for any new decision that's hard to undo.
- **Incidents are written up** in the [incident log](./incidents/README.md), one file per incident.

## Ansible vs Terraform

We currently use two IaC tools, and are part way through a migration:

| Layer                                  | Tool          | Where                                                                  | Long-term plan            |
|----------------------------------------|---------------|------------------------------------------------------------------------|---------------------------|
| Host OS configuration                  | Ansible       | [plays/configure-hosts.yml](../plays/configure-hosts.yml)              | **Stays in Ansible**      |
| k3s installation                       | Ansible       | `xanmanning.k3s` role (external, see [requirements.yml](../requirements.yml)) | Stays in Ansible          |
| Cluster-level services (Helm releases etc) | Ansible   | [plays/configure-cluster.yml](../plays/configure-cluster.yml), roles in [roles/](../roles/) | Migrating to Terraform    |
| Newer cluster services                 | Terraform     | `coven/platform/` and `coven/apps/`, using modules in [tfmodules/](../tfmodules/) | Terraform                 |
| GCP project, DNS zones, cloud resources | Terraform    | Mostly `coven/bootstrap/`; DNS records for apps in `coven/apps/`        | Terraform                 |
| Self-deploying apps                    | The app's own repo | GitHub Actions in each app repo, deploying with Helm into its own namespace | Unchanged         |

When working out how to fix something, first find out which of these owns it, as that tells you where the change
needs to be made. Because the migration is in progress, some functionality exists in both forms (e.g., the
`create_object_store` task in `omelette.storage` and the `tfmodules/object-store` module, or the Keycloak client and
Vault secret syncing tasks in Ansible and the `keycloak-client` and `vault-k8s-secret` modules). New work should
prefer Terraform; host-level configuration stays in Ansible.

### What Ansible manages

Host level (runs against every node, as root):

- `omelette.hostbase` - hostname, timezone (UTC) and the EPEL repository
- `omelette.auto-updates` - `dnf-automatic` applying OS updates automatically, plus a textfile exporter that reports
  when a reboot is needed (feeds the `NodeNeedsRestarting` alert)
- `omelette.ssh-users` - SSH users and keys (the `ssh_users` group var)
- `omelette.wireguard` - the WireGuard tunnel from strix to the home network (see [Networking](#networking)), plus a
  textfile exporter for handshake metrics
- `omelette.k3s-backup` - a systemd timer snapshotting the k3s datastore to GCS every 6 hours, and restoring it if it's
  missing (controller only)
- `xanmanning.k3s` - installs and configures k3s
- `omelette.storage` (host part) - iSCSI tools needed by Longhorn

Cluster level (runs from the machine running Ansible, against the k8s API). Roles are run in this order, which
roughly reflects their dependencies:

| Role                            | Namespace(s)                          | What it deploys                                                              |
|---------------------------------|---------------------------------------|------------------------------------------------------------------------------|
| `omelette.storage`              | `longhorn-system`                     | Longhorn (default storage class), nightly backup and daily snapshot recurring jobs |
| `omelette.monitoring`           | `monitoring`                          | kube-prometheus-stack, Loki (+ RustFS object store), Alloy, blackbox exporter, helm-exporter, alert rules, Traefik metrics config |
| `omelette.cert-manager`         | `cert-manager`                        | cert-manager with Let's Encrypt and Vault PKI issuers, HTTPS redirect middleware |
| `omelette.postgres`             | `cnpg-system`                         | CloudNativePG operator and barman-cloud backup plugin                        |
| `omelette.sso`                  | `keycloak`                            | Keycloak (auth.coven.omelette.gay) and its Postgres cluster                  |
| `omelette.secrets`              | `vault`, `external-secrets`           | Vault (vault.coven.omelette.gay), External Secrets Operator, Vault auth methods and policies |
| `omelette.external-dns`         | `external-dns`                        | external-dns writing records to Hetzner DNS                                  |
| `omelette.outbound-mail`        | `mail`                                | Postfix SMTP relay used by Grafana, Alertmanager and apps                    |
| `omelette.mariadb`              | `mariadb-system`                      | MariaDB operator                                                             |
| `omelette.apps`                 | per app                               | Namespaces, Vault roles, secret syncing and Keycloak clients for self-deploying apps (see [deploying apps](./deploying-apps.md)) |
| `omelette.factorio`             | `factorio-<server_id>`                | Factorio servers                                                             |
| `omelette.planka`               | `planka`                              | Planka (boards.omelette.gay) and its Postgres cluster                        |

### What Terraform manages

Terraform state is stored in the `coven-tfstate` GCS bucket. The `coven/` folder is production; `testlab/` is the
local Vagrant VM. Each environment has three stacks, each with its own state, applied in order (see
[ADR 002](./adr/002-three-stack-terraform-for-cluster-configuration.md) for what goes where):

- `bootstrap/` - operators, CRDs and base services, and on coven the cloud resources everything else needs. It can't
  use Vault, so on coven it reads the Hetzner token from `HCLOUD_TOKEN`.
- `platform/` - configures Vault and Keycloak, and runs services that apps depend on.
- `apps/` - leaf services that nothing else in the cluster depends on.

The bootstrap and platform stacks are shared modules (`tfmodules/stack-bootstrap/` and `tfmodules/stack-platform/`),
so both environments run the same platform. Apps differ between environments, so each environment's `apps/` defines
them directly.

Between them, they manage:

- GCP project resources: APIs, the `coven-backups` bucket (with a 14-day expiry on objects under `k3s/` only) and backup
  service account (with keys rotated every 30
  days and written into Vault), the `k3s-cluster-token` secret, GitHub Actions workload identity, billing budget alerts
- Hetzner DNS zones and static records (Fastmail, Bluesky verification)
- `glitchtip` namespace - GlitchTip error tracking (errors.omelette.gay)
- `minecraft-<server_id>` namespaces - Minecraft servers
- `trivy-system` namespace - Trivy Operator vulnerability scanning
- A namespace per retired domain (e.g. `cjn-me-uk`) - redirects to the domain that replaced it

### Self-deploying apps

Apps listed under `k8s_github_deployment_roles` in [coven/inventory/group_vars/all](../coven/inventory/group_vars/all)
deploy themselves from their own GitHub repos, using Vault to obtain credentials scoped to their namespace. This repo
only sets up the namespace's access, secrets and SSO client. If an alert is for one of those namespaces (e.g.
`wedding`, `home-assistant`, `weight-tracker`, `pling-org-uk`, `chrisn-xyz`), the workload itself is defined in the
app repo listed against it, not here.

### Things k3s provides itself

k3s ships with some components that are not deployed by us directly: Traefik (ingress, in `kube-system`), CoreDNS,
metrics-server, ServiceLB (`svclb-*` pods) and the local-path provisioner. We customise Traefik through a
`HelmChartConfig` in `omelette.monitoring` (enabling metrics, the dashboard and a plugin). Longhorn is made the
default storage class instead of local-path.

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
- Workloads that must use a datacentre IP (e.g. outbound mail, the Minecraft server) are pinned or prefer
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

The Ansible jobs (in [.github/workflows/host_config.yml](../.github/workflows/host_config.yml), and the
"Configure Coven cluster" job at the end of [.github/workflows/tfapply.yml](../.github/workflows/tfapply.yml)) bring up
their own WireGuard peer (192.168.178.204) to janus before running the playbook, so they can reach grimhilde, and take
it down again afterwards. They share a concurrency group, so only one uses the peer at a time. If that tunnel can't be
established (for example because janus or the home internet connection is down), they will fail. The Terraform jobs
only talk to the Kubernetes API on strix, Vault and cloud APIs, so they don't need the tunnel.

## Platform services

| Concern              | What we use                                                                                     |
|----------------------|--------------------------------------------------------------------------------------------------|
| Ingress / reverse proxy | Traefik (k3s built-in). See [HTTPS](./https.md)                                              |
| TLS certificates     | cert-manager, `letsencrypt` ClusterIssuer (prod), `vault` issuer for the testlab                  |
| DNS                  | Hetzner DNS; zones in Terraform, records from Ingresses created by external-dns                 |
| Block storage        | Longhorn, 2 replicas by default (one per node), best-effort data locality, replica timeout increased to 30s because replication goes over the internet, snapshots checksummed on creation (fast-check) and fast replica rebuild enabled |
| Object storage       | RustFS (S3-compatible), currently used as Loki's backend                                        |
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

## Alerting

- Alert rules are Prometheus rules. Our own rules are defined in `additionalPrometheusRulesMap` in
  [roles/omelette.monitoring/tasks/install_kube-prometheus.yml](../roles/omelette.monitoring/tasks/install_kube-prometheus.yml);
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
new services, new roles or Terraform modules, and moving existing Ansible config to Terraform. Bug fixes for
problems on coven don't need to go through the testlab first. When suggesting a fix while diagnosing an issue,
treat it as a bug fix; if the fix needs something new to be built, say that it should be tried in the testlab first.
See the [README](../README.md#testlab) for how to set up the testlab.
