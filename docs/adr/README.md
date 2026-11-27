# Architecture decision records

An architecture decision record (ADR) captures one significant decision: the problem, what we chose, what else we
considered, and what we're accepting as a result. The code shows *what* we do. ADRs record *why*, so that later on we
(or an AI agent) can tell whether a decision still holds before changing it.

## When to write one

Write one when a decision would be hard to reverse, affects how the cluster is built or run, or is likely to make
someone later ask "why on earth do we do it like this?" For example: choosing or replacing a tool or service, changing
how something is backed up or deployed, or deliberately going against a convention. Routine changes, version bumps and
bug fixes don't need one.

Add the ADR in the same pull request as the change it describes, so they're reviewed together, and add it to the
[index](#index) below.

## File names

`NNN-short-description.md`, for example `001-replace-litestream-with-snapshots.md`.

- `NNN` is three digits, one more than the highest number already used. Numbers are never reused.
- The description is the decision, in lowercase words separated by hyphens.

## Changing a decision

Once an ADR is accepted, don't rewrite it. If the decision changes, write a new ADR, and set the old one's status to
`Superseded by` with a link to the new one. That way the history of why things changed is kept. Fixing typos and broken links
is fine.

## Format

Files are GitHub-flavoured Markdown. Use the template below.

```markdown
# NNN: <Decision>

| | |
|---|---|
| **Status** | Proposed / Accepted / Deprecated / Superseded by [NNN](./NNN-....md) |
| **Date** | YYYY-MM-DD |
| **Related** | Links to incidents, pull requests or other ADRs |

## Context

The problem, and the facts and constraints that shape the decision.

## Decision

What we're doing, stated plainly.

## Alternatives considered

Each option, and why we didn't choose it.

## Consequences

What we gain, what we give up, and what we'll need to watch for.
```

## Index

| ADR | Decision | Status |
|---|---|---|
| [001](./001-replace-litestream-with-snapshots.md) | Replace Litestream with periodic datastore snapshots | Accepted |
| [002](./002-three-stack-terraform-for-cluster-configuration.md) | Use three layered Terraform stacks for cluster configuration | Accepted |
| [003](./003-update-dependencies-within-ranges-through-lock-files.md) | Update dependencies within version ranges through lock files, and group non-major Helm chart updates | Accepted; grouping superseded by 004 |
| [004](./004-bundle-renovate-updates-weekly.md) | Bundle non-major Renovate updates into weekly pull requests by area | Accepted |
| [005](./005-publish-a-filtered-copy-of-this-repository-as-coven.md) | Publish a filtered copy of this repository as a new public repository, `coven` | Accepted |
| [006](./006-gate-ci-credentials-by-workflow-and-environment.md) | Only `main`'s workflows get CI credentials, and Renovate's plans need approval | Accepted |
| [007](./007-manage-keycloak-group-roles-in-code-and-membership-in-the-ui.md) | Manage Keycloak groups and their roles in code, and group membership in the UI | Accepted |
