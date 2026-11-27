# 007: Manage Keycloak groups and their roles in code, and group membership in the UI

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-26 |
| **Related** | [#140](https://github.com/omelette-gay/coven/issues/140); [single sign-on](../sso.md); [ADR 002](./002-three-stack-terraform-for-cluster-configuration.md) |

## Context

Who can do what in our apps comes from Keycloak client roles granted to groups (see [single sign-on](../sso.md)). Every
client and its roles are made by Terraform, and the `keycloak-client` module could grant a client's roles to groups.
Those grants were not exhaustive: they added a role to a group without removing anything else, because a group holds
roles from many clients and the module only knows about one. So a role granted to a group by hand in the Keycloak UI
stayed there, and nothing in the repo showed it.

The `admins` group gets Vault admin, which can read every secret and issue cluster-admin credentials, so a hand-made
grant to the wrong group could give someone full control without a pull request.

The roles `admins` holds come from two stacks. The platform stack makes the `admins` group and the Vault and Grafana
clients, and Vault's login needs `vault-admin` granted before anyone can log in with SSO on a fresh cluster. The apps
stack makes the clients for self-deploying apps such as Home Assistant, and is applied after platform.

Group membership could also be managed in Terraform, but the repo is public and plans are posted to pull requests, so
the usernames of everyone in a group would be published.

## Decision

- **Each group, and the full list of roles it holds, is in the apps stack's `sso-groups.tf`**, with
  `keycloak_group_roles` and `exhaustive = true`. A role granted to the group in the UI is removed on the next apply.
  Apps' roles come from the `keycloak-client` module's `role_ids` output, and the platform stack's roles are looked up
  with data sources.
- **The `keycloak-client` module no longer grants roles.** It creates them and outputs their IDs, so there's one place
  to read what each group can do.
- **The platform stack still grants `vault-admin` and `grafana-admin` to `admins`, without `exhaustive`**, so Vault and
  Grafana work on a fresh cluster before the apps stack has been applied. The `admins` group itself stays in the
  platform stack, as Vault's configuration refers to it.
- **Who is in each group is managed in the Keycloak UI**, not in code.

## Alternatives considered

- **Keep non-exhaustive grants in each client's module.** Simple, but grants made by hand are never removed, which is
  the problem this decision fixes.
- **Make `admins`' roles exhaustive in the platform stack.** The platform stack can't refer to the apps stack's
  clients, which don't exist yet when it's applied, so it would remove Home Assistant's `admin` role from `admins` on
  every apply.
- **Move every role grant to the apps stack.** Vault SSO wouldn't work on a fresh cluster until the apps stack had
  been applied, and the apps stack is the one most likely to fail during a rebuild.
- **Manage group membership in Terraform as well.** It would revert someone adding themselves to `admins` by hand, but
  it would publish the usernames of everyone in every group, including friends. Only Chris and Meg can change
  membership in the UI, so it isn't the weak point.

## Consequences

- A role grant shows up in a pull request and its plan, and a grant made in the UI is reverted on the next apply.
- `vault-admin` and `grafana-admin` are granted in two places. Removing one of them from `admins` means changing both,
  or the platform stack adds it back before the apps stack removes it on each apply.
- Reverting only happens when the apps stack is applied, which is on merge to `main`. A hand-made grant lasts until
  then.
- Roles granted directly to a user, rather than to a group, aren't covered. None exist today, and we don't grant roles
  that way.
- Membership, including of `admins`, is still only visible in the Keycloak UI.
