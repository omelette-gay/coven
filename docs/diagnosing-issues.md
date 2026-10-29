# Diagnosing Issues

This is a guide to investigating alerts and errors on the coven cluster. It is written so that an AI agent can follow
it, but humans should find it useful too. Read the [cluster overview](./cluster-overview.md) first for how the cluster
is put together.

## Ground rules

- **Investigate read-only first.** `get`, `describe`, `logs`, `top`, PromQL and LogQL queries are always safe.
  Anything that changes state (deleting pods, scaling, rolling back Helm releases, restarting services, rebooting
  hosts) should be proposed to a human and confirmed before it is done.
- **Never try to unseal or re-initialise Vault.** The unseal keys are stored offline and only humans hold them. If
  Vault is sealed, report it and stop there.
- **Don't run `ansible-playbook` or `terraform apply` against coven.** These deploy from GitHub Actions on merge
  to `main`. A durable fix is a change to this repo (or the app's repo) that goes through a pull request.
- **Remember manual changes get overwritten.** If you change something by hand as a temporary mitigation, say so
  clearly, as the next Ansible/Terraform run may revert it (or fail because of it).
- **Correlate before concluding.** Because the two nodes are joined by a WireGuard tunnel over the internet, one
  network problem can cause a burst of unrelated looking alerts. Look at everything that is firing, not just the
  alert you were given.

## Tools available

| Tool                 | What it's good for                                                     | How to get to it                                       |
|----------------------|------------------------------------------------------------------------|--------------------------------------------------------|
| `kubectl`            | Current state of workloads, events, pod logs                           | `./login.sh --coven`; if Vault/Keycloak is down, `./bootstrap-auth.sh --coven` (see below) |
| `helm`               | Release status and history for anything deployed with Helm              | Uses the same kubeconfig as kubectl                    |
| `kubectl cnpg`       | Status of CloudNativePG Postgres clusters                               | kubectl plugin                                         |
| Prometheus           | Metrics, alert rule definitions, what is currently firing               | port-forward (below)                                   |
| Alertmanager         | Active alerts with all their labels, silences                           | port-forward (below)                                   |
| Grafana              | Dashboards, and Explore for both Prometheus and Loki                    | https://monitoring.coven.omelette.gay (SSO)            |
| Loki                 | Pod logs, host systemd journals, Kubernetes events (kept for 12 weeks)  | Grafana Explore, or port-forward and `logcli`          |
| SSH                  | Host-level issues: k3s itself, WireGuard, disks, OS updates, k3s datastore backups | `ssh strix.xdc.omelette.gay`; grimhilde at 192.168.178.36 from the home network (see below) |
| Traefik dashboard    | Routing problems: which routers/services/middlewares exist and their errors | port-forward (below)                                |
| Longhorn UI          | Volume, replica, node and backup health                                 | port-forward (below)                                   |
| GlitchTip            | Application exceptions from apps that report to it                      | https://errors.omelette.gay                            |
| `git log` on this repo | What changed recently (including Renovate upgrades)                   | Local checkout, or GitHub                              |
| GitHub Actions       | Whether the last Ansible/Terraform deploy succeeded                     | The repo's Actions tab                                 |

### Getting cluster credentials

Use `./login.sh --coven` normally. It gets a short-lived token from Vault after you log in with Keycloak SSO.

The SSO login is interactive. The script opens a browser for a human to sign in to Keycloak, and blocks until they
have. **If you are an AI agent, don't run `login.sh` yourself**; it will hang waiting for a browser login you can't
complete. Check whether credentials are already in place with `kubectl config current-context` (it should be
`coven`) and `kubectl auth can-i get pods -A`. If they aren't, or if commands start failing with `Unauthorized`
because the token has expired, ask a human to run `./login.sh --coven`, then carry on.

If Vault is sealed or Keycloak is down, `login.sh` will fail. In that case use `./bootstrap-auth.sh --coven`
instead. It isn't interactive, but because it gives break-glass credentials, an agent should check with a human
before running it. It SSHes to
strix and copies the k3s admin client certificate into your kubeconfig, so it only needs SSH access to strix. These
credentials are full cluster-admin and don't expire quickly, so treat them as break-glass: use them for the
investigation and go back to `login.sh` once Vault is available. A failing `login.sh` is itself a clue, as it
usually means Vault is sealed (see [`VaultIsSealed`](#vaultissealed)) or Keycloak has a problem, not that the API
server is down.

### Reaching the hosts

We normally work from the home network, which can reach both nodes: strix at `strix.xdc.omelette.gay` and
grimhilde directly on the LAN at 192.168.178.36. From anywhere else, grimhilde can only be reached by jumping
through strix (`ssh -J strix.xdc.omelette.gay 192.168.178.36`), and that only works while strix's WireGuard tunnel
is up. GitHub Actions reaches grimhilde through its own WireGuard tunnel to janus. See the
[cluster overview](./cluster-overview.md#how-people-and-automation-reach-the-nodes).

### Port-forwards

None of these are exposed to the internet. Each command blocks while the forward is open.

```shell
# Prometheus - http://localhost:9090
kubectl -n monitoring port-forward svc/kube-prometheus-kube-prome-prometheus 9090:9090

# Alertmanager - http://localhost:9093
kubectl -n monitoring port-forward svc/kube-prometheus-kube-prome-alertmanager 9093:9093

# Loki - http://localhost:3100
kubectl -n monitoring port-forward svc/loki-gateway 3100:80

# Traefik dashboard - http://localhost:8080/dashboard/
kubectl -n kube-system port-forward deployments/traefik 8080:8080

# Longhorn UI - http://localhost:8000/
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8000:80
```

The Traefik dashboard is enabled in "insecure" mode, which is fine as it isn't exposed anywhere other than through a
port-forward.

## A general approach

### 1. Understand the alert

Get the full set of labels for what's firing, as `namespace`, `pod`, `instance`, `node` etc. tell you where to look:

```shell
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | {alert: .labels.alertname, labels, summary: .annotations.summary, startsAt}'
```

Find the rule's expression. Our own rules are in `additionalPrometheusRulesMap` in
[roles/omelette.monitoring/tasks/install_kube-prometheus.yml](../roles/omelette.monitoring/tasks/install_kube-prometheus.yml);
upstream rules can be found from the cluster:

```shell
kubectl get prometheusrules -A
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name=="<AlertName>")'
```

Many upstream kube-prometheus-stack alerts have a `runbook_url` annotation which is worth reading.

Then run the alert's expression yourself in Prometheus to see the current value and which series are involved.

### 2. Work out what changed

Most incidents follow a change. Check:

- `git log --since="3 days ago" --oneline` in this repo, especially Renovate chart bumps (`Update Helm release ...`)
- Whether the last GitHub Actions deploys (Ansible and Terraform) succeeded
- `helm -n <namespace> history <release>` for the affected release
- For self-deployed apps, recent deploys in the app's own repo
- Whether a node has recently rebooted or had OS updates (`uptime`, `dnf history` on the host)
- Whether backup credentials have just been rotated (every 30 days by Terraform)

It's also worth searching the [incident log](./incidents/README.md) for the alert or symptom, in case it's happened
before.

### 3. Look at the current state

```shell
kubectl get nodes -o wide
kubectl get pods -A -o wide | grep -v -E 'Running|Completed'
kubectl get events -A --sort-by=.lastTimestamp | tail -50
kubectl -n <namespace> describe pod <pod>
kubectl -n <namespace> logs <pod> [-c <container>] [--previous]
kubectl top nodes
kubectl top pods -A --sort-by=memory
helm list -A --failed --pending
```

Use `-o wide` so you can see which node things are on; problems that only affect one node usually point at that
node or the network between them.

### 4. Query metrics

Use Grafana's dashboards for an overview, or query Prometheus directly:

```shell
curl -s http://localhost:9090/api/v1/query --data-urlencode 'query=up == 0' | jq '.data.result[].metric'
```

Some useful starting queries:

| Question                                  | PromQL                                                                 |
|-------------------------------------------|------------------------------------------------------------------------|
| Which scrape targets are down?            | `up == 0`                                                              |
| Which HTTP probes are failing?            | `probe_success == 0`                                                   |
| Pods restarting a lot                     | `increase(kube_pod_container_status_restarts_total[1h]) > 3`           |
| Containers being OOM killed               | `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}` |
| Node memory available                     | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes`          |
| Node disk space                           | `node_filesystem_avail_bytes{fstype!~"tmpfs\|overlay"} / node_filesystem_size_bytes` |
| WireGuard last handshake age (seconds)    | `time() - wireguard_latest_handshake_seconds`                          |
| k3s datastore backup age (seconds)        | `time() - k3s_datastore_backup_last_success_timestamp_seconds`         |
| Does a node need a reboot?                | `node_reboot_required`                                                 |
| Longhorn volume health                    | `longhorn_volume_robustness`                                           |
| Helm release states                       | `helm_chart_info` (negative is failed, 0 unknown, above 4 pending)     |

### 5. Search logs

Logs are collected by Alloy and stored in Loki. Use Grafana Explore with the Loki data source, or `logcli` with the
port-forward above (`logcli --addr=http://localhost:3100 query '<LogQL>'`). The labels available are:

| Source               | Labels                                                                           |
|----------------------|----------------------------------------------------------------------------------|
| Pod logs             | `namespace`, `pod`, `container`, `app`, `instance`, `component`, `node_name`, `job` (`<namespace>/<app>`) |
| Host systemd journal | `service="systemd-journal"`, `unit`, `node_name`                                  |
| Kubernetes events    | `job="kubernetes-events"`, `namespace`, `reason`, `type`                          |

Example queries:

```logql
# errors from a namespace
{namespace="keycloak"} |~ "(?i)error|exception"

# k3s itself on the controller
{service="systemd-journal", node_name="strix.xdc.omelette.gay"} | json | _SYSTEMD_UNIT =~ "k3s.*"

# warning events across the cluster
{job="kubernetes-events", type="Warning"}
```

Kubernetes only keeps events for about an hour, so Loki is the place to look for events from earlier incidents.
Note that journal logs are only picked up when they are less than 12 hours old, so if Alloy has been down for longer
than that, check the host directly.

### 6. Look at the hosts

SSH in when the problem looks like it is below Kubernetes (node `NotReady`, k3s crashing, networking, disks), or when
kubectl isn't available. strix runs Rocky Linux 9 and grimhilde runs Rocky Linux 10, so package versions and the
output of host tools can differ between the two.

```shell
cat /etc/rocky-release
uptime
df -h                                   # Longhorn data lives under /var/lib/longhorn, k3s under /var/lib/rancher/k3s
free -h
systemctl list-units 'k3s*'             # find the k3s service, then:
journalctl -u <k3s service> --since "1 hour ago"
sudo k3s kubectl get nodes              # on strix only - works even when Vault/SSO is down and the API isn't reachable remotely
sudo k3s crictl ps -a                   # containers on this node, even if the API server is down
sudo k3s crictl logs <container-id>
sudo wg show                            # strix only - WireGuard peer and last handshake
cat /run/node-exporter/*.prom           # our textfile metrics (reboot required, WireGuard, k3s datastore backups)
needs-restarting -r                     # whether the node needs a reboot
dnf history | head                      # recent automatic updates
systemctl list-timers k3s-datastore-backup.timer  # strix only - when the k3s datastore was last/next backed up
journalctl -u k3s-datastore-backup      # strix only - output of the k3s datastore backups
```

From strix, you can check the tunnel to the home network with `ping 192.168.178.36` (grimhilde) and
`ping 192.168.178.1`.

## Specific alerts and problems

### `VaultIsSealed`

Vault has restarted (e.g. the pod was rescheduled, the node rebooted, or Ansible changed Vault's config) and needs
unsealing with the offline keys. While it's sealed, External Secrets can't sync, Terraform and Ansible can't run,
and `./login.sh` won't work - so expect `ExternalSecretSyncError` alongside it.

**This needs a human.** For reference, the procedure is: if Vault was changed by Ansible, restart it first with
`kubectl -n vault delete pod vault-0` (otherwise it'll break itself in the middle of a run), then unseal with
`kubectl -n vault exec -it vault-0 -- vault operator unseal` (or SSH to the host and run it as root there if you
can't get k8s credentials). The UI won't be available until it is unsealed.

While Vault is sealed, `./login.sh` won't work, so get credentials with `./bootstrap-auth.sh --coven` to
investigate. To check the state without changing anything: `kubectl -n vault exec vault-0 -- vault status`.

### `WireguardPeerDown`, `LonghornNodeDown`, grimhilde `NotReady`

These usually mean strix can't reach the home network: the home internet connection, janus (the router), grimhilde
itself, or the tunnel. Check:

- `sudo wg show` on strix - when was the last handshake?
- `systemctl status wg-quick@wg0` on strix
- Whether the `janus.gs.omelette.gay` DNS record still points at the home IP (it is managed by external-dns from
  `external_dns_extra_records`)
- Whether grimhilde is up and reachable from the home network (ping or SSH to 192.168.178.36). If it can be reached
  from home but not from strix, the problem is the tunnel or janus, not grimhilde.

If this happens during a deploy, the "Configure Coven hosts" GitHub Actions workflow will also fail, because it
needs its own WireGuard tunnel to janus to reach grimhilde.

Expect Longhorn volumes to go degraded and HTTP probes for anything running on grimhilde to fail at the same time.
Once connectivity is restored, Longhorn will rebuild replicas on its own.

### `LonghornVolumeStatusWarning` / `LonghornVolumeStatusCritical`

A degraded volume has lost one of its two replicas; a faulted one has lost all of them. Check whether a node is
down first (see above). Then:

```shell
kubectl -n longhorn-system get volumes.longhorn.io
kubectl -n longhorn-system get replicas.longhorn.io -o wide
kubectl -n longhorn-system get nodes.longhorn.io
```

The Longhorn UI gives a clearer picture of rebuild progress. Replication goes over the WireGuard tunnel, so a slow
or flapping home connection can cause repeated degradation.

Degraded volumes are expected for a while after a node reboot (including a rolling reboot) while replicas rebuild.
Rebuilds only copy data written since the volume's last checksummed snapshot, so they're usually quick, but a
volume with a lot of churn since its last snapshot can take a while. Rebuilding replicas on strix is limited by the
home internet upload speed (about 109 Mbps), as the data comes from grimhilde. Restoring from backup is covered in
[backups and recovery](./backups-and-recovery.md), and needs a human.

### `LonghornNodeStorageWarning` / `LonghornDiskStorageWarning`

Disk usage is over 70%. Longhorn is configured to allow over-provisioning, so volumes may have been created that
together exceed the available space. Find which volumes are using the space in the Longhorn UI, and check host disk
usage with `df -h`. Loki (`loki_storage_size`) and Prometheus (20Gi) are common large consumers.

### Backup alerts (`LonghornNoRecentBackups`, `MariaDBBackupFailed`, `MariaDBBackupStale`, `LastFailedArchiveTime`)

All backups go to the `coven-backups` GCS bucket. Common causes:

- The backup credentials secret is missing or out of date in the namespace - check the relevant `ExternalSecret`
  (keys are rotated every 30 days)
- Vault is sealed, so the secrets couldn't sync
- The GCP project has a problem (e.g. billing)

```shell
kubectl -n longhorn-system get backups.longhorn.io --sort-by=.status.backupCreatedAt | tail
kubectl get backups.postgresql.cnpg.io -A
kubectl cnpg status <cluster> -n <namespace>
kubectl get physicalbackups -A
```

For the k3s datastore, see [`K3sDatastoreBackupStale`](#k3sdatastorebackupstale--k3sdatastorebackupmissing).

### `K3sDatastoreBackupStale` / `K3sDatastoreBackupMissing`

The k3s datastore is snapshotted to GCS by the `k3s-datastore-backup` systemd timer on strix (see
[backups and recovery](./backups-and-recovery.md#k3s-control-plane--sqlite-state)). `K3sDatastoreBackupStale` fires
when the last successful backup is more than twice the backup interval old (12 hours by default).
`K3sDatastoreBackupMissing` fires when there's no record of a backup ever succeeding. The success time is kept on disk
and restored after a reboot, so a reboot alone won't trigger it. It normally means the very first backup on a host
failed, or node-exporter isn't being scraped on strix (in which case other alerts will be firing too).

These alerts aren't urgent in themselves, as nothing is broken until the datastore is lost, but don't leave them: old
snapshots are deleted after 14 days whether or not there are newer ones.

On strix:

```shell
systemctl list-timers k3s-datastore-backup.timer      # is the timer scheduled?
systemctl status k3s-datastore-backup                  # did the last run fail?
journalctl -u k3s-datastore-backup --since "1 day ago" # why?
cat /run/node-exporter/k3s-datastore-backup.prom
```

Common causes:

- **Authentication errors from rclone.** Terraform rotates the backup service account key every 30 days and deletes the
  old one, but strix only gets the new key when Ansible runs. Re-run the "Configure Coven hosts" GitHub Actions
  workflow.
- **"not enough free space".** The backup won't run unless there's at least twice the size of the datastore free in
  `/var/tmp`, so that it can never fill the disk the datastore is on. Check `df -h /var`.
- **Integrity check failures.** The snapshot is checked with `PRAGMA integrity_check` before it's uploaded. A failure
  here could mean the live datastore is corrupt, which is serious: tell a human straight away, and don't restart k3s.
- **The GCP project has a problem** (e.g. billing), as with the other backups.

Running `sudo systemctl start k3s-datastore-backup` takes a backup straight away (it's safe to run at any time, but
confirm with a human first as with any change). To check that the newest backup could be restored, without touching
the live datastore, run `sudo k3s-datastore-backup-verify`.

### Leader-election controllers restarting on both nodes, `Slow SQL` in the k3s logs

If controllers that use leader election (the CNPG operator, plugin-barman-cloud, the Longhorn CSI sidecars, etc.) keep
restarting on both nodes with errors about failing to renew their lease, and `KubePodCrashLooping` flaps for them, the
k3s datastore is probably too slow to write to. Check the k3s logs on strix for `Slow SQL` warnings:

```logql
{service="systemd-journal", node_name="strix.xdc.omelette.gay"} |= "Slow SQL"
```

Leases have to be renewed within a few seconds, so even short write stalls cause this. Check whether the disk is slow
(the node-exporter disk dashboards in Grafana) or whether something else is holding the SQLite database open or locked. Check the size of
`/var/lib/rancher/k3s/server/db/state.db-wal` too: it should normally stay small. This happened in October 2026
because of Litestream; see the
[incident write-up](./incidents/2026-10-23-litestream-stalled-k3s-datastore-writes.md).

### `ExternalSecretSyncError`

```shell
kubectl get externalsecret -A
kubectl -n <namespace> describe externalsecret <name>
kubectl get secretstore -A
kubectl -n external-secrets logs deploy/external-secrets
```

Usually Vault is sealed, the Vault role/policy for that namespace is missing, or the secret doesn't exist in Vault.
The roles are created by `omelette.secrets` (`create_k8s_secret` task) or the `vault-k8s-secret` Terraform module.

### `CertManagerCertNotReady` / `CertManagerCertExpirySoon` / `TraefikTLSCertificatesExpiring`

```shell
kubectl get certificates -A
kubectl get certificaterequests,orders,challenges -A
kubectl -n <namespace> describe certificate <name>
kubectl -n cert-manager logs deploy/cert-manager
```

We use the HTTP-01 challenge via Let's Encrypt, so the hostname must resolve to strix and be reachable through
Traefik. A stuck challenge often means DNS is wrong (check external-dns) or the Ingress isn't being served (check the
Traefik dashboard). Watch for `CertManagerHittingRateLimits` - repeatedly retrying can lock us out for a week.

### `ExternalDnsErrors`

```shell
kubectl -n external-dns logs deploy/external-dns
```

Usually a Hetzner API problem or a bad/expired API token (`gitops/hetzner` in Vault).

### `HttpProbeFailed`

A blackbox exporter `Probe` failed for the URL in the `instance` label. Work along the request path:

1. Does DNS resolve to strix?
2. Is the certificate valid?
3. Does Traefik have a router for the host (Traefik dashboard)? Are there errors there?
4. Is the backing Service's endpoints list empty (`kubectl -n <ns> get endpoints`)? Are the pods ready?
5. What do the app's logs say? If the pods are on grimhilde, is the tunnel up?

### `HelmDeployFailed` / `HelmDeployStuck` / `HelmDeployUnknown`

```shell
helm list -A --failed --pending
helm -n <namespace> history <release>
helm -n <namespace> status <release>
```

A release left in a `pending-*` state blocks future upgrades, so the next Ansible/Terraform run will fail. Check the
GitHub Actions run that did the deploy for the error. Recovery is usually `helm rollback`, but confirm with a human
first, and check whether the release is owned by Ansible, Terraform or an app repo.

### `NodeNeedsRestarting`

OS updates have been applied by `dnf-automatic` that need a reboot. This isn't urgent. The fix is a human running
`uv run ansible-playbook -i coven/inventory plays/rolling-reboot.yml`, which does each node in turn.

### Postgres alerts

```shell
kubectl get clusters.postgresql.cnpg.io -A
kubectl cnpg status <cluster> -n <namespace>
kubectl -n <namespace> logs <cluster>-<n>
```

Each cluster normally has a primary and a replica on different nodes. After a reboot both can end up on the same
node; the rolling reboot playbook rebalances this. `PostgresReplicationRoleChanged` fires on any switchover, which
is expected during a rolling reboot.

### `TraefikConfigReloadFailuresIncreasing` and routing problems

Use the Traefik dashboard to find the router or middleware that's failing, and check Traefik's logs:

```shell
kubectl -n kube-system logs deploy/traefik
```

A typical cause is an Ingress referencing a middleware (e.g. `kube-system-redirect-https@kubernetescrd`) or secret
that doesn't exist. Traefik is configured through a `HelmChartConfig` in
[roles/omelette.monitoring/tasks/traefik_monitoring.yml](../roles/omelette.monitoring/tasks/traefik_monitoring.yml).

### The Kubernetes API is unreachable

strix is the only controller, so:

1. Can you SSH to strix? If not, the host or its network is down - check the Hetzner Robot console (needs a human).
2. Is the k3s service running? Check its journal for errors.
3. Is the disk full (`df -h`)? SQLite and containerd both fail badly when out of space.
4. If `./login.sh` is what's failing, the API might be fine but Vault or Keycloak might not be. Try
   `./bootstrap-auth.sh --coven` and then `kubectl get nodes`, or run `sudo k3s kubectl get nodes` on strix.

If the datastore is lost, it can be restored from the snapshots in GCS - see
[backups and recovery](./backups-and-recovery.md#disaster-recovery-rebuilding-the-controller). This needs a human.

### Vulnerability reports

Trivy Operator scans running images. These are informational rather than alerts, but are available with
`kubectl get vulnerabilityreports -A` and in the Trivy Grafana dashboards.

## Reporting back

When you've finished investigating, report:

- Which alerts were firing, and which you think share a root cause
- What you checked, and the evidence (commands and their relevant output)
- The likely root cause, and how confident you are
- Whether it has resolved itself or is ongoing
- Suggested fixes, split into immediate mitigations (needing human approval) and durable changes (which file in
  this repo, or which app repo, should change)

If it was a real incident (see [when to write one](./incidents/README.md#when-to-write-one)), draft a write-up for the
[incident log](./incidents/README.md) from what you found, using the template there, and include it in the pull
request for the fix. If the fix involves a significant decision, draft an [ADR](./adr/README.md) for it too.
