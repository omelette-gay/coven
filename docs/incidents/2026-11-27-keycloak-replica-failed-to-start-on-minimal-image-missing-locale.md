# Keycloak's database replica failed to start on the minimal image, which lacks the locale its config names

| | |
|---|---|
| **Status** | Ongoing (fix in the pull request that adds this file) |
| **Detected** | 2026-11-27, when `CNPGClusterHACritical` fired for `keycloak/db-cluster`. The exact time hasn't been checked: `ALERTS{alertname="CNPGClusterHACritical"}` in Prometheus has it |
| **Impact started** | 2026-11-27 20:48 UTC, when the operator restarted the replica on the new image |
| **Resolved** | |
| **Severity** | Minor (Keycloak stayed up, but its database had no replica to fail over to) |
| **Alerts** | `CNPGClusterHACritical` |

## Summary

Moving Keycloak's CNPG cluster to the shared image catalog
([ADR 009](../adr/009-take-postgres-images-from-a-shared-image-catalog.md)) changed its image from the legacy
`postgresql:16` to `16.16-…-minimal-trixie`. The replica restarted on the new image and Postgres refused to start,
because `postgresql.conf` set `lc_messages`, `lc_monetary`, `lc_numeric` and `lc_time` to `en_US.utf8`, a locale the
minimal images don't have. The fix sets those four parameters to `C.UTF-8` in the cluster spec.

## Impact

- `keycloak/db-cluster` ran on its primary (`db-cluster-1`, on strix) alone from 20:48 UTC. Had strix or the primary
  failed in that time, Keycloak, and so SSO for every app, would have gone down with no automatic failover.
- Keycloak itself kept working. The operator doesn't switch over until the updated replica is healthy, so the primary
  stayed on the old image.
- No data was lost. The 20:30 UTC scheduled backup had completed before the change.

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-11-27 20:46 | [Pull request #157](https://github.com/omelette-gay/coven/pull/157) merged and its apply starts |
| 2026-11-27 20:48 | The operator restarts `db-cluster-2` on the catalog's image. Its startup probe starts failing |
| 2026-11-27 ~20:50 | `CNPGClusterHACritical` fires (time not confirmed) |
| 2026-11-27 ~21:00 | Investigated. Root cause found in the replica's logs |
| 2026-11-27 ~21:05 | The fix confirmed locally against the minimal image with Docker |

## Root cause

`initdb` writes `lc_messages`, `lc_monetary`, `lc_numeric` and `lc_time` into `postgresql.conf` from the environment,
even when collation and ctype are set to `C`. The legacy `postgresql:16` image sets `LANG=en_US.utf8`, so every
database created on it, about 460 days ago for Keycloak, has those four lines set to `en_US.utf8`. The minimal images
only have the `C`, `C.utf8` and `POSIX` locales, and Postgres treats an invalid value in its config file as fatal.

ADR 009 says every database uses `C` collation, which is true and is why there's no `REINDEX` risk, and concluded that
we don't need the extra locales. It missed these four settings, which aren't collation.

The testlab didn't catch it. Its Keycloak database was only a day old, probably created on the catalog's image (not
checked), so its config wouldn't name `en_US.utf8`. Vikunja and GlitchTip's databases on coven were created on minimal
images, so they're not affected.

## How we found it

```shell
kubectl get clusters.postgresql.cnpg.io -A        # keycloak: 1 of 2 ready, "Waiting for the instances to become active"
kubectl get events -n keycloak --sort-by=.lastTimestamp
kubectl -n keycloak logs db-cluster-2 -c postgres | grep -m1 'startup value of a parameter' | jq -r .stderr
```

The last command printed Postgres's own messages:

```
LOG:  invalid value for parameter "lc_messages": "en_US.utf8"
LOG:  invalid value for parameter "lc_monetary": "en_US.utf8"
LOG:  invalid value for parameter "lc_numeric": "en_US.utf8"
LOG:  invalid value for parameter "lc_time": "en_US.utf8"
FATAL:  configuration file "/var/lib/postgresql/data/pgdata/postgresql.conf" contains errors
```

The rest of the replica's log is metrics-collection errors and `startup probe failing`, which only say that Postgres
isn't running.

## Resolution

Set the four parameters to `C.UTF-8` in `cluster.postgresql.parameters` in `tfmodules/keycloak/main.tf`. CNPG writes
these to a file included at the end of `postgresql.conf`, and when a setting appears more than once Postgres only
applies the last value, so the invalid earlier lines are ignored. This was checked in the
`16.16-202611230809-minimal-trixie` image: with the `en_US.utf8` lines alone Postgres failed with the same error, and
with a later include setting `C.UTF-8` it started.

## Lessons

- The operator's rollout order (replica first, switch over only once it's healthy) meant a broken image cost us
  redundancy rather than the database.
- The useful error was in a JSON `stderr` field, buried among metrics errors. The diagnosing doc now says where to look.
- Testing on the testlab can't catch problems that depend on how old a database is. Check the oldest databases'
  config before changing their image.

## Follow-up actions

- [ ] Merge the fix and confirm `db-cluster-2` starts, the cluster finishes its switchover and the alert clears
- [ ] Add the same parameters to the wedding site and Home Assistant's databases, also created on the legacy image,
  before they move to the catalog (omelette-gay/wedding#292, omelette-gay/home-assistant#85)

## References

- [Pull request #157](https://github.com/omelette-gay/coven/pull/157), which moved Keycloak to the catalog
- [ADR 009](../adr/009-take-postgres-images-from-a-shared-image-catalog.md)
- [docs/diagnosing-issues.md, Postgres alerts](../diagnosing-issues.md#postgres-alerts)
