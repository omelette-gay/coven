# Vikunja exhausted its database's connections during a bulk update and restarted

| | |
|---|---|
| **Status** | Resolved |
| **Detected** | 2026-11-27 21:39 UTC, when API calls from the Vikunja MCP connector started returning 502 Bad Gateway |
| **Impact started** | 2026-11-27 21:39 UTC |
| **Resolved** | 2026-11-27 21:43 UTC |
| **Severity** | Minor |
| **Alerts** | None |

## Summary

A bulk update marking 34 tasks as done made Vikunja open more database connections than Postgres allows. A new
connection was refused, Vikunja exited, and Kubernetes restarted it, so the API returned 502s for about a minute.
Vikunja's connection pool had no limit set, so it used its default of 100, which is more than its Postgres cluster
accepts. The fix caps the pool at 20, and does the same for Keycloak, which had the same problem waiting to happen.

## Impact

Vikunja's web app and API were unavailable for about a minute from 21:39 UTC. The bulk update itself completed. A
second update, sent just after it, failed with a 502 and wasn't applied, and was resent once Vikunja was back. No data
was lost.

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-11-27 21:39:22 | A bulk update (`PUT /api/v2/tasks/bulk`) marks 34 tasks in House Improvements as done. It succeeds in 847ms |
| 2026-11-27 21:39:23.400 | Vikunja logs `Failed to begin database transaction ... FATAL: remaining connection slots are reserved for roles with the SUPERUSER attribute (SQLSTATE 53300)` and exits with code 1 |
| 2026-11-27 21:39 | Kubernetes restarts the container. API calls return 502 Bad Gateway until it's ready |
| 2026-11-27 21:40 | Vikunja is serving again (its readiness probe failed once while it started) |
| 2026-11-27 21:43 | The failed update is checked, found not to have been applied, and resent |

## Root cause

Postgres in the `db-cluster` CNPG cluster has `max_connections = 100` and `superuser_reserved_connections = 3`, so it
accepts at most 97 connections from the `vikunja` user, fewer once CNPG's own sessions are counted. Vikunja's
`database.maxopenconnections` wasn't set, so it used its default of 100, and its pool could ask for more connections
than Postgres would give it.

In normal use Vikunja holds only a handful of connections (6 idle shortly after the incident). The error came 175ms
after the bulk update's response was sent, so it came from work done after the request rather than the request
itself. The likely explanation is that each of the 34 tasks' update events was handled concurrently, each with its
own connection, which grew the pool past the limit in under a second. This hasn't been confirmed from Vikunja's code.

Vikunja treats a failure to begin a transaction there as fatal and exits, so one refused connection took the whole
app down rather than failing one request.

Keycloak had the same mismatch: `db-pool-max-size` defaults to 100, it wasn't set, and Keycloak's Postgres also has
`max_connections = 100`. GlitchTip is a Django app that opens connections per worker rather than through one large
pool, and holds 2 idle connections, so it isn't affected.

## How we found it

The Vikunja container's last state was `Error`, exit code 1, finishing at 21:39:23, and its previous logs end with the
`SQLSTATE 53300` error, which means Postgres has no non-superuser connection slots left:

```bash
kubectl get pods -n vikunja -l app.kubernetes.io/name=vikunja -o custom-columns='NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,REASON:.status.containerStatuses[0].lastState.terminated.reason,EXIT:.status.containerStatuses[0].lastState.terminated.exitCode,FINISHED:.status.containerStatuses[0].lastState.terminated.finishedAt'
kubectl logs -n vikunja deploy/vikunja --previous --tail=20
```

The limits and the current connections, from the primary (the same works for the `keycloak` and `glitchtip`
namespaces):

```bash
PRIMARY=$(kubectl get pod -n vikunja -l cnpg.io/cluster=db-cluster,cnpg.io/instanceRole=primary -o name)
kubectl exec -n vikunja $PRIMARY -c postgres -- psql -U postgres -c "SHOW max_connections;" -c "SHOW superuser_reserved_connections;"
kubectl exec -n vikunja $PRIMARY -c postgres -- psql -U postgres -c "SELECT usename, state, count(*) FROM pg_stat_activity GROUP BY 1,2 ORDER BY 3 DESC;"
```

A few idle connections soon afterwards pointed to a burst rather than a leak. The Vikunja deployment's environment and
config set no pool limits, and [Vikunja's config docs](https://vikunja.io/docs/config-options) give the default
`maxopenconnections` as 100.

## Resolution

Vikunja restarted on its own. To stop it happening again:

- Vikunja's config sets `database.maxopenconnections = 20` and `database.maxidleconnections = 5`, so a burst queues
  inside Vikunja instead of exhausting Postgres.
- Keycloak sets `KC_DB_POOL_MAX_SIZE = 20` for the same reason. It runs a single replica, so 20 is well within its
  database's limit.

## Lessons

- The apps' pool defaults were larger than their databases could serve, and nothing checked that the two were
  compatible. The same check is worth doing whenever an app gets a CNPG cluster.
- No alert fired. The `vikunja-https` probe runs once a minute and the outage was shorter than that, so it was
  missed. That's acceptable for an outage this short that recovers on its own.
- Until the caps are applied, bulk changes through the API should be split into batches of about 10.

## Follow-up actions

- [x] Find out how Vikunja restarted: it exited with code 1 after the database error, and Kubernetes restarted it
- [x] Check whether any alert fired: none did, which is acceptable for an outage this short
- [x] Check other apps on their own CNPG clusters for pool defaults at or above `max_connections`: Keycloak was
  affected and is fixed in the same pull request; GlitchTip isn't. Self-deploying apps are defined in their own repos
  and weren't checked

## References

- [Vikunja config options](https://vikunja.io/docs/config-options)
- [Keycloak configuration: `db-pool-max-size`](https://www.keycloak.org/server/all-config)
