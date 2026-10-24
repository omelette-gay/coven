# 001: Replace Litestream with periodic datastore snapshots

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-10-24 |
| **Related** | [Incident: Litestream stalled k3s datastore writes](../incidents/2026-10-22-litestream-stalled-k3s-datastore-writes.md), pull requests #787 and `we-hate-litestream` |

## Context

The k3s datastore is a SQLite database on strix, our only controller. It holds all Kubernetes state, and if it's lost,
the cluster has to be rebuilt. We need it backed up off the host.

From 2026-10-22 we used Litestream to replicate it continuously to GCS. That caused an
[incident](../incidents/2026-10-22-litestream-stalled-k3s-datastore-writes.md). Litestream holds a long-running read
transaction and takes over WAL checkpointing. Because kine (k3s's SQLite layer) writes constantly, SQLite's own
checkpoints couldn't complete, the WAL grew to 186 MB, and forced checkpoints stalled writes for up to 17 seconds.
Every leader-elected controller then failed to renew its lease and restarted, on both nodes. Litestream was also
expensive in GCS operations.

Some facts shape what we need:

- Almost everything in the datastore is recreated by Ansible, Terraform and app deploys. The stateful data that
  matters is backed up separately by Longhorn, CloudNativePG and MariaDB. So losing a few hours of cluster state on a
  restore is acceptable: our recovery point objective (RPO) is a few hours, not seconds.
- Whatever we use must not hold the datastore open or locked for long, or we'll repeat the incident.
- A failed backup must never affect k3s.

## Decision

Take a snapshot of the datastore every 6 hours instead of replicating it continuously:

- A systemd timer on the controller runs a script that takes a consistent online copy using SQLite's backup API in a
  single step, opening the database read-only. It runs `PRAGMA integrity_check` on the copy, compresses it, and
  uploads it to `gs://coven-backups/k3s/<host>/` with a timestamped name.
- The timer uses `OnCalendar=` with `Persistent=true`, so a backup missed while strix was down runs when it boots, and
  a random delay of up to 30 minutes.
- Uploads use **rclone** from EPEL, with the backup service account's JSON key.
- A GCS lifecycle rule deletes snapshots under `k3s/` after 14 days.
- The disaster recovery step in Ansible restores the newest snapshot if the datastore is missing, before k3s starts.
- The backup records when it last succeeded as a node-exporter textfile metric, and the `K3sDatastoreBackupStale` and
  `K3sDatastoreBackupMissing` alerts watch it.

## Alternatives considered

**Keep Litestream, but tune it.** Litestream's design depends on holding a read transaction open and controlling
checkpoints. Lowering the sync frequency (which we tried in #801, to cut costs) doesn't change that. With kine's
constant writes, any continuous replicator that works this way will contend with k3s. We don't need second-level RPO,
so it isn't worth the risk.

**The `sqlite3` CLI's `.backup` command.** This was our first choice for taking the snapshot, but it doesn't work
under kine's write load. The CLI calls `sqlite3_backup_step()` 100 pages at a time and releases its lock between
steps, and SQLite restarts the backup from the beginning whenever another connection writes in between. In testing,
it couldn't back up a 100 MB database within a minute with only 20 writes a second. Python's
`sqlite3.Connection.backup()` uses the same API but copies everything in one step, under one read transaction that
lasted about 0.3 seconds for 100 MB at up to 100 writes a second. Python is always on the hosts, as Ansible needs it.

**`VACUUM INTO`.** It performed the same as the single-step backup in testing, and would have worked. We chose the
backup API as it produces a page-for-page copy of the database rather than a rebuilt one.

**Copying `state.db` and its WAL directly.** This gives a torn, possibly corrupt copy while k3s is writing.

**Upload tools other than rclone:**

- `gcloud storage`: a whole SDK with its own Python and an extra repository, just to upload one file.
- `curl --aws-sigv4` with the HMAC credentials: needs no new packages, but Rocky 9's curl (7.76) dates from soon after
  the feature was added in 7.75, and we couldn't test it against GCS before deploying.
- curl with a hand-written OAuth JWT using `openssl`: needs no new packages, but it's authentication code we'd have to
  maintain and debug ourselves.

rclone is a single binary that reads the service account key directly, retries, verifies uploads, and can also list
and download for the restore. Enabling EPEL in `omelette.hostbase` to get it was preferred over installing an
unsigned RPM from GitHub.

## Consequences

- **We can lose up to about 6.5 hours of cluster state** on a restore (the 6-hour interval plus up to 30 minutes of
  random delay). We accept this because the rest is recreated by our deploys and the data has its own backups.
- The backup holds a read transaction for well under a second every 6 hours, instead of permanently.
- **A snapshot is not encrypted as a whole.** Most of the cluster's state (object specs, ConfigMaps and so on) is in
  plaintext, so the bucket must be treated as sensitive. Two things in it are protected:
  - Secrets are encrypted by the API server, as `secrets-encryption: true` is set, and are stored as `k8s:enc:...`.
  - k3s keeps the encryption config, the cluster CA certificates and keys, and the service account signing key in the
    datastore as "bootstrap data", under `/bootstrap/<first 12 hex characters of sha256(token)>`. It's encrypted with
    AES-GCM using a key derived from the cluster token with PBKDF2 (see `pkg/cluster/encrypt.go` in k3s).

  So **a snapshot can only be restored with the same cluster token**. The token is in GCP Secret Manager
  (`k3s-cluster-token`), not Vault, so it's available when the cluster is down.
- GCS lifecycle rules can't keep a minimum number of snapshots. If backups stop for 14 days, every snapshot is
  deleted. `K3sDatastoreBackupStale` fires after 12 hours, long before that.
- The service account key on strix only changes when Ansible runs, but Terraform rotates it every 30 days and deletes
  the old one. If nothing is merged after a rotation, backups fail until the "Configure Coven hosts" workflow runs
  again. This was also true for Litestream. The alert catches it.
- EPEL is now enabled on all hosts, so `dnf-automatic` applies updates from it too.
- **Anything that holds a long-lived connection to the k3s datastore, or locks it, risks repeating this incident.**
  Consider that before adding any tool that touches it.
