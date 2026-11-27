# Vikunja exhausted its database's connections during a bulk update and restarted

| | |
|---|---|
| **Status** | Mitigated |
| **Detected** | 2026-11-27 21:39 UTC, when API calls from the Vikunja MCP connector started returning 502 Bad Gateway |
| **Impact started** | 2026-11-27 21:39 UTC |
| **Resolved** | Not yet: resolved once the connection pool cap is applied |
| **Severity** | Minor |
| **Alerts** | None known. It's not known whether the `vikunja-https` probe caught the outage, as it only runs once a minute |

## Summary

A bulk update marking 34 tasks as done made Vikunja open more database connections than Postgres allows. New
connections were refused, Vikunja restarted, and the API returned 502s for about four minutes. Vikunja's connection
pool had no limit set, so it used its default of 100, which is more than its Postgres cluster accepts. The fix caps the
pool at 20.

## Impact

Vikunja's web app and API were unavailable from about 21:39 to 21:43 UTC. The bulk update itself completed. A second
update, sent just after it, failed with a 502 and wasn't applied, and had to be resent once Vikunja was back. No data was
lost.

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-11-27 21:39:22 | A bulk update (`POST /tasks/bulk`) marks 34 tasks in House Improvements as done, and succeeds |
| 2026-11-27 21:39:23 | Vikunja logs `Failed to begin database transaction ... FATAL: remaining connection slots are reserved for roles with the SUPERUSER attribute (SQLSTATE 53300)` and restarts |
| 2026-11-27 21:39 | The next API call, and every call for the next few minutes, returns 502 Bad Gateway |
| 2026-11-27 21:43 | Vikunja is back. The failed update is checked, found not to have been applied, and resent |

## Root cause

Postgres in the `db-cluster` CNPG cluster has `max_connections = 100` and `superuser_reserved_connections = 3`, so it
accepts at most 97 connections from the `vikunja` user, fewer once CNPG's own sessions are counted. Vikunja's
`database.maxopenconnections` wasn't set, so it used its default of 100, and its pool could ask for more connections
than Postgres would give it.

In normal use Vikunja holds only a handful of connections (6 idle shortly after the incident). The bulk update changed
34 tasks at once. It's likely that each task's update events were handled concurrently, each with its own connection,
so the pool grew past the limit in under a second. This hasn't been confirmed from Vikunja's code.

## How we found it

The Vikunja pod's log at the time of the restart showed `SQLSTATE 53300`, which means Postgres has no non-superuser
connection slots left. The limits and the current connections, from the primary:

```bash
PRIMARY=$(kubectl get pod -n vikunja -l cnpg.io/cluster=db-cluster,cnpg.io/instanceRole=primary -o name)
kubectl exec -n vikunja $PRIMARY -c postgres -- psql -U postgres -c "SHOW max_connections;" -c "SHOW superuser_reserved_connections;"
kubectl exec -n vikunja $PRIMARY -c postgres -- psql -U postgres -c "SELECT usename, state, count(*) FROM pg_stat_activity GROUP BY 1,2 ORDER BY 3 DESC;"
```

A few idle connections soon afterwards pointed to a burst rather than a leak. The Vikunja deployment's environment and
config set no pool limits, and [Vikunja's config docs](https://vikunja.io/docs/config-options) give the default
`maxopenconnections` as 100.

## Resolution

Vikunja's config now sets `database.maxopenconnections = 20` and `database.maxidleconnections = 5`, so a burst queues
inside Vikunja instead of exhausting Postgres.

## Lessons

- The pool default was larger than the database could serve, and nothing checked that the two were compatible.
- It wasn't clear whether any alert fired, so we may not have known if it had happened while nobody was using Vikunja.
- Until the cap is applied, bulk changes through the API should be split into batches of about 10.

## Follow-up actions

- [ ] Check `kubectl describe pod` for how Vikunja restarted (crash or failed liveness probe), and fill it in above
- [ ] Check whether `vikunja-https` or any other alert fired during the outage
- [ ] Check other apps on their own CNPG clusters for pool defaults at or above `max_connections`

## References

- [Vikunja config options](https://vikunja.io/docs/config-options)
