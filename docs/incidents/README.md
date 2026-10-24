# Incident log

One file per incident, so we can see what went wrong before, how we found it, and what we changed because of it. When
an alert looks familiar, search here first.

## When to write one

Write one for anything that affected the cluster or the services on it and needed a person to diagnose or fix it: an
outage, a degraded service, data loss or a near miss, or a burst of alerts with a shared cause. Don't write one for an
alert that resolved itself with no action, or one with an obvious cause and fix (e.g. `NodeNeedsRestarting`).

Write it while the details are fresh, ideally as part of the pull request that fixes it, and add it to the
[index](#index) below.

## File names

`YYYY-MM-DD-short-description.md`, for example `2026-10-22-litestream-stalled-k3s-datastore-writes.md`.

- The date is when the impact started, in UTC. If that isn't known, use the date the change that caused it went live.
- The description says what happened, in lowercase words separated by hyphens. Describe the cause where it's known,
  rather than just the alert that fired.

## Format

Files are GitHub-flavoured Markdown. Use the template below. Times are UTC. If something isn't known, say so (and how
someone could find out) rather than leaving it out or guessing. Keep it blameless: describe what happened and why the
system allowed it, not who did it.

```markdown
# <Title>

| | |
|---|---|
| **Status** | Ongoing / Mitigated / Resolved |
| **Impact started** | YYYY-MM-DD HH:MM UTC |
| **Resolved** | YYYY-MM-DD HH:MM UTC |
| **Severity** | Minor / Major / Critical |
| **Alerts** | `AlertName`, ... |

## Summary

Two or three sentences: what broke, why, and how it was fixed.

## Impact

What users and services saw, and for how long.

## Timeline

| Time (UTC) | Event |
|---|---|
| YYYY-MM-DD HH:MM | ... |

## Root cause

## How we found it

The evidence, and the commands or queries that showed it, so the same checks can be used next time.

## Resolution

What fixed it, and links to the pull requests.

## Lessons

What went well, what didn't, and where we got lucky.

## Follow-up actions

- [ ] ...

## References

Links to pull requests, ADRs and docs.
```

## Index

| Date | Incident | Status |
|---|---|---|
| 2026-10-22 | [Litestream stalled k3s datastore writes, crash-looping leader-elected controllers](./2026-10-22-litestream-stalled-k3s-datastore-writes.md) | Mitigated |
