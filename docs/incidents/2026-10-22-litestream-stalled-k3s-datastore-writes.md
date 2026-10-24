# Litestream stalled k3s datastore writes, crash-looping leader-elected controllers

| | |
|---|---|
| **Status** | Mitigated (Litestream stopped by hand on strix; permanent fix in review) |
| **Impact started** | 2026-10-23 19:19 UTC (first alert). Litestream had been running since it was deployed by hand on 2026-10-22, so writes may have been stalling for a while before that without alerting. |
| **Resolved** | Not yet (see [follow-up actions](#follow-up-actions)) |
| **Severity** | Major |
| **Alerts** | `KubePodCrashLooping` (flapping) |

## Summary

Litestream, added to continuously replicate the k3s SQLite datastore to GCS, stopped SQLite from checkpointing the WAL
normally. The WAL grew to 186 MB, and the forced checkpoints stalled kine's writes for up to 17 seconds. Every controller
using leader election missed its 5-second lease renewal deadline and exited, on both nodes, so `KubePodCrashLooping`
kept flapping. Stopping Litestream by hand mitigated it. It's being replaced by periodic snapshots
([ADR 001](../adr/001-replace-litestream-with-snapshots.md)).

## Impact

- Every leader-elected controller restarted repeatedly on both nodes, including the CloudNativePG operator,
  plugin-barman-cloud and the Longhorn CSI sidecars. While they were restarting, nothing reconciled the resources they
  manage (Postgres clusters and their backups, Longhorn volume attach, detach and provisioning).
- Kubernetes API writes were slow throughout, as every write goes through the same SQLite database.
- We don't know of any data loss or user-visible outage. Running Postgres instances and mounted volumes don't depend
  on their controllers being up.
- Litestream also ran up a noticeable bill in GCS operations while it was running.

## Timeline

> [!NOTE]
> The times of the manual deploy, the diagnosis and the manual stop weren't recorded. They may be in strix's
> journal (`journalctl -u litestream`). Please fill them in.

| Time (UTC) | Event |
|---|---|
| 2026-10-22, time not recorded | Litestream deployed to strix by hand, before #787 had been reviewed or merged. The change was committed at 21:14 UTC. |
| 2026-10-23 17:44 | #787 merged, adding Litestream to `omelette.k3s-backup`. The deploy leaves Litestream running on strix, where it already was. |
| 2026-10-23 18:05 | #794 merged: Renovate bumps Litestream from 0.5.14 to 0.5.17. |
| 2026-10-23 19:19 | First `KubePodCrashLooping` alert for leader-elected controllers; it keeps flapping from then on. This was about 1h15m after the 0.5.17 upgrade deployed. Whether the upgrade made things worse, or the stalls had just built up enough to trip the alert, isn't known. |
| 2026-10-24 13:52 | #801 merged: Litestream's sync and compaction frequency reduced, to cut GCS operation costs. |
| 2026-10-24 14:32 | #804 merged: Litestream config updated to the 0.5 format. |
| 2026-10-24, time unknown | Cause identified as Litestream. Litestream stopped by hand on strix, and the `Slow SQL` count drops dramatically within the hour. |
| 2026-10-24 | Fix to replace Litestream with periodic snapshots opened for review. |

## Root cause

k3s stores the cluster state in SQLite through kine, which writes constantly (mostly lease renewals). In WAL mode,
writes go to the WAL file, and SQLite periodically checkpoints the WAL back into the main database. A checkpoint can
only get as far as the oldest open read transaction.

To replicate continuously, Litestream holds a long-running read transaction on the database and takes over
checkpointing itself. With kine writing all the time, SQLite's own passive checkpoints never got a chance to complete,
so the WAL kept growing, to 186 MB. When Litestream then forced checkpoints, those blocked writers while they ran.
Writes that normally take milliseconds took up to 17 seconds.

Controllers that use leader election must renew their `Lease` within a deadline (5 seconds here) or give up
leadership and exit. With writes stalling for longer than that, every one of them failed to renew, exited, was
restarted, and failed again.

## How we found it

- `KubePodCrashLooping` was firing for a set of unrelated controllers on **both** nodes, which pointed away from a
  single node or workload and towards something they all share: the API server and its datastore.
- The restarting containers' logs showed they were exiting because they failed to renew their leases.
- k3s on strix logged `Slow SQL` warnings for inserts taking up to 17 seconds:

  ```logql
  {service="systemd-journal", node_name="strix.xdc.omelette.gay"} |= "Slow SQL"
  ```

- Disk latency on strix was unchanged, so this was lock contention, not slow I/O.
- `/var/lib/rancher/k3s/server/db/state.db-wal` had grown to 186 MB, which meant checkpoints weren't completing.
- Litestream was the one thing recently added that held the database open. Stopping it for an hour made the
  `Slow SQL` count drop dramatically, which confirmed it.

## Resolution

- **Mitigation:** Litestream was stopped by hand on strix. Note that it would have been started again by the next
  merge to `main`, as the role set it to `state: started`.
- **Fix:** the `we-hate-litestream` pull request removes Litestream from strix completely. It replaces it with a
  systemd timer that takes a consistent snapshot of the datastore every 6 hours and uploads it to GCS, with alerts
  if the backups stop. See [ADR 001](../adr/001-replace-litestream-with-snapshots.md) for why, and
  [backups and recovery](../backups-and-recovery.md#k3s-control-plane--sqlite-state) for how it works.

## Lessons

**What went well**

- Correlating alerts across both nodes quickly pointed to a shared dependency rather than individual workloads.
- Disabling Litestream for an hour was a cheap, reversible experiment that confirmed the cause.

**What didn't go well**

- Litestream went straight to coven. The docs say new features should go to the testlab first, but the testlab
  couldn't have reproduced this, as it doesn't run enough controllers to write to the datastore constantly. Load-related
  problems like this one may only ever show up on coven.
- Something that holds a long-lived connection to the k3s datastore is risky in a way that wasn't obvious when it was
  added. This is now written down in [diagnosing issues](../diagnosing-issues.md) and ADR 001.
- Litestream was deployed to coven by hand before its pull request was reviewed and merged. So it ran for about a day
  without review, and the merge time (the obvious place to look when asking "what changed?") was a day later than
  when it actually started. Changes should reach coven through GitHub Actions on merge to `main`, so that `git log`
  tells the truth about what is running.
- The mitigation was fragile: the role would have restarted Litestream on any merge to `main`.
- The cost of GCS operations wasn't considered up front.

**Where we got lucky**

- Running Postgres instances and mounted volumes kept working while their controllers restarted, so the impact stayed
  on the control plane.

## Follow-up actions

- [ ] Merge the `we-hate-litestream` pull request and run the post-deploy checks in its description, including
      `sudo k3s-datastore-backup-verify` on strix.
- [ ] Confirm the leader-election restart counts stop climbing and `Slow SQL` warnings stop after the deploy, and after
      the first scheduled backup.
- [ ] In a later pull request, delete `roles/omelette.k3s-backup/tasks/remove_litestream.yml` once it has run on coven.
- [ ] Fill in the unknown times in the [timeline](#timeline), then mark this incident resolved.

## References

- [ADR 001: Replace Litestream with periodic datastore snapshots](../adr/001-replace-litestream-with-snapshots.md)
- [Backups and recovery: k3s control plane & SQLite state](../backups-and-recovery.md#k3s-control-plane--sqlite-state)
- Pull requests #787 (added Litestream), #794, #801 and #804
