# The new Vikunja database couldn't archive WAL to GCS, so it was never backed up and its disk filled

| | |
|---|---|
| **Status** | Resolved |
| **Detected** | 2026-11-22 19:31 UTC, when `LastFailedArchiveTime` fired. It was first looked at on 2026-11-25 after `CNPGClusterLowDiskSpaceWarning` |
| **Impact started** | 2026-11-22 ~19:29 UTC, when the cluster was created |
| **Resolved** | 2026-11-25 11:21 UTC |
| **Severity** | Minor (no data lost and Vikunja stayed up, but its database had no backups and was about 16 hours from a full disk) |
| **Alerts** | `LastFailedArchiveTime`, `LongRunningTransaction`, `CNPGClusterLowDiskSpaceWarning` |

## Summary

Vikunja's new CNPG cluster couldn't archive any WAL to the `coven-backups` bucket, because the backup service account
had `roles/storage.objectAdmin`, which doesn't include the `storage.buckets.get` permission that Barman Cloud needs
before a new cluster archives its first WAL file. No backup ever completed, and unarchived WAL filled the primary's
volume. The fix grants the account `roles/storage.legacyBucketReader` on the bucket.

## Impact

- The Vikunja database had no backups or WAL archive from its creation until the fix was applied. If the primary's
  volume had been lost in that time, everything in Vikunja would have been lost too.
- The first scheduled backup, `db-cluster-daily-backup-20261122192854`, stuck in `started`. No later scheduled
  backups ran.
- WAL built up on the primary (`db-cluster-1`) at about 2.3 GB a day, reaching 3.5 GB of the 5 Gi volume (71%) on
  2026-11-25 11:00 UTC. At that rate it would have filled the volume and stopped Postgres about 16 hours later.
- Vikunja itself kept working. The replica wasn't affected.
- Other CNPG clusters (Keycloak, wedding, GlitchTip, Home Assistant) kept backing up with the same key.

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-11-22 ~19:29 | Vikunja deployed to coven. CNPG cluster `vikunja/db-cluster` created, and its first backup started |
| 2026-11-22 19:31 | First WAL archive fails with a `403`. `LastFailedArchiveTime` fires |
| 2026-11-22 19:36 | `LongRunningTransaction` fires on `db-cluster-1`, probably the stuck backup (not confirmed) |
| 2026-11-25 08:34 | `CNPGClusterLowDiskSpaceWarning` fires |
| 2026-11-25 ~11:00 | Investigated. 218 WAL files waiting to be archived. Root cause found in the plugin sidecar's logs |
| 2026-11-25 ~11:17 | Bucket IAM change applied locally by a project owner |
| 2026-11-25 11:18 | WAL archiving starts working. `LastFailedArchiveTime` and `LongRunningTransaction` resolve |
| 2026-11-25 11:19 | The stuck first backup completes, followed by a catch-up scheduled backup |
| 2026-11-25 11:21 | WAL backlog archived and the primary's volume down to 58%. `CNPGClusterLowDiskSpaceWarning` resolves |

## Root cause

`coven/bootstrap/backups.tf` gave the `coven-backup` service account `roles/storage.objectAdmin` on the bucket. That
covers reading and writing objects, but not reading the bucket itself. Before a new CNPG cluster archives its first WAL
file, `barman-cloud-check-wal-archive` reads the bucket (`GET /storage/v1/b/coven-backups`), and that needs
`storage.buckets.get`. The check fails, so archiving never starts, and the backup waits for WAL that never gets
archived.

The other clusters didn't fail because they passed that check long ago, and archiving and backups after that only
touch objects. As far as we know, Vikunja's was the first new CNPG cluster created on coven since the binding became
`objectAdmin`, so nothing hit the problem before. When and why that changed hasn't been checked. The history of the
binding before the October 2026 move into the three stacks is in omelette-gay/gitops.

The testlab didn't catch it either. Its backups go to a different bucket, and Vikunja is disabled on the testlab.

Postgres keeps WAL files until they've been archived, and CNPG's `archive_timeout` of 5 minutes switches to a new
16 MB file at least every 5 minutes, so even an idle database fills its volume within a few days.

## How we found it

```shell
kubectl get clusters.postgresql.cnpg.io -A                 # all healthy
kubectl get backups.postgresql.cnpg.io -n vikunja           # one backup, `started` for 2.5 days
kubectl -n vikunja logs db-cluster-1 -c plugin-barman-cloud | grep -i error
```

The sidecar logged this every minute:

```
ERROR: Can't connect to cloud provider: 403 GET https://storage.googleapis.com/storage/v1/b/coven-backups?fields=name&prettyPrint=false:
coven-backup@coven-omelette-gay.iam.gserviceaccount.com does not have storage.buckets.get access to the Google Cloud Storage bucket.
```

Postgres logged `archiving write-ahead log file "000000010000000000000001" failed too many times`. The disk growth and
the WAL backlog came from Prometheus:

```promql
deriv(kubelet_volume_stats_used_bytes{namespace="vikunja",persistentvolumeclaim=~"db-cluster-.*"}[24h]) * 86400
cnpg_collector_pg_wal_archive_status{namespace="vikunja",value="ready"}
```

## Resolution

Granted the backup service account `roles/storage.legacyBucketReader` on `coven-backups`, as well as
`objectAdmin`. CI's `roles/editor` can't change bucket IAM, so a project owner applies the bootstrap stack from their
own machine and then merges the pull request.

Within a minute of the apply, the sidecar archived the backlog of 218 WAL files, the stuck first backup completed, and
the primary's volume went from 71% to 58%. The code change is in
[pull request #152](https://github.com/omelette-gay/coven/pull/152).

## Lessons

- The alerts worked: `LastFailedArchiveTime` fired within two minutes of the cluster being created. It just took two
  and a half days for someone to investigate, and it was the disk space warning that got attention.
- The plugin sidecar's logs named the missing permission exactly, so once someone looked, the cause took minutes to
  find.
- We were lucky the database was new and small. On a busier database, the volume would have filled sooner.

## Follow-up actions

- [x] Apply the bootstrap stack locally as a project owner
- [x] Confirm the WAL backlog is archived, the backup completes and the alerts clear

## References

- [Pull request #152](https://github.com/omelette-gay/coven/pull/152)
- [docs/diagnosing-issues.md, Postgres alerts](../diagnosing-issues.md#postgres-alerts)
- [docs/backups-and-recovery.md](../backups-and-recovery.md)
