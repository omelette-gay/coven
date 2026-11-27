# 008: Put an OAuth gateway in front of Vikunja's MCP server, with each person's Vikunja token in their access token

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-27 |
| **Related** | [#144](https://github.com/omelette-gay/coven/issues/144), [#106](https://github.com/omelette-gay/coven/issues/106); [tfmodules/agentgateway](../../tfmodules/agentgateway/), [tfmodules/vikunja](../../tfmodules/vikunja/) |

## Context

We want Claude to read and update our tasks in Vikunja through MCP, from claude.ai, as each of us rather than one shared
identity. We only use MCP servers through claude.ai. This is a new way into our data.

Vikunja 2.8 has an MCP server at `/api/v2/mcp`. It only takes Vikunja API tokens with the `mcp:access` scope, and
checks every call against that token's permissions and its user's. It rejects JWTs and doesn't do OAuth. claude.ai's
custom connectors need OAuth, so something has to sit in front: log people in with Keycloak, and turn their Keycloak
identity into their Vikunja token.

Vikunja has no trash or undo, so we don't want Claude to be able to delete tasks or projects.

## Decision

**[agentgateway](https://agentgateway.dev/), from its standalone Helm chart, takes over `/api/v2/mcp` on
`tasks.omelette.gay`** (and its OAuth protected resource metadata). Everything else on the host still goes to
Vikunja, so the MCP endpoint keeps the address Vikunja documents. It's configured entirely by values, in a generic
`tfmodules/agentgateway` module that `tfmodules/vikunja` calls.

**Each person's Vikunja token is a Keycloak user attribute, `vikunja_mcp_token`, copied into their access token.**
They paste it in themselves on their account page. A user attribute mapper on the `vikunja-mcp` client (only) puts it
in that client's access tokens, and an audience mapper sets their audience to the MCP endpoint's URL. The gateway
checks the access token against Keycloak's keys, refuses it if the claim is missing, and replaces the `Authorization`
header with `Bearer <vikunja_mcp_token>`. Vikunja never sees the access token.

**Deletes are stopped by Vikunja, not the gateway.** Each person creates their token without delete permissions.

**Only claude.ai is supported.** The `vikunja-mcp` client only allows claude.ai's callback addresses, and Vikunja
tokens are no longer accepted at `/api/v2/mcp`, so other MCP clients such as Claude Code can't use it. The rest of
the API still takes Vikunja tokens.

## Alternatives considered

**Keep the Vikunja tokens in Vault, keyed by Keycloak `sub`, and have the gateway look them up.** Keeps the tokens out
of access tokens and encrypted at rest, but the gateway would need Vault access and a page for people to enter their
token. claude.ai holds a Keycloak refresh token either way, which can get access to Vikunja for as long as the session
lasts, so keeping the token out of the access token only helps if an access token alone leaks.

**Have the gateway read the attribute through Keycloak's admin API.** Keeps the token out of access tokens, but the
gateway would need a service account that can read every user in the realm.

**Write our own gateway with FastMCP.** A working proof of concept was about 50 lines, but it would mean a repository,
image and chart of our own to maintain, for what agentgateway does through configuration.

**Block destructive tools at the gateway with an allowlist.** Vikunja's `do_action` tool reaches the rest of the API,
so an allowlist of tool names can't stop deletes, and it would need updating as Vikunja adds tools. Token permissions
are enforced by Vikunja for every route, and also apply outside MCP.

**agentgateway's Kubernetes mode.** Needs the Gateway API and its own control plane. We use Traefik, and one route
doesn't justify them.

**A separate hostname for the gateway.** Works, but the same host keeps Vikunja's documented address and reuses its
certificate.

## Consequences

- Each person's Vikunja token is in their access tokens for `vikunja-mcp`, which only go to claude.ai and the
  gateway. Access tokens are short-lived, but the token inside them isn't: if one leaks, the
  Vikunja token has to be revoked in Vikunja. The mapper must never go in a shared client scope, or every app would
  get everyone's Vikunja token.
- The tokens are stored unencrypted in Keycloak's database, so they're also in its backups in GCS, and realm admins can
  read them. That's an exception to keeping secrets in Vault. For two people who are both admins, we accept it.
- The realm's user profile is now managed by Terraform, which means repeating Keycloak's default attributes. A Keycloak
  upgrade that changes the defaults won't change ours.
- Keycloak's default SSO session idle time is 30 minutes, so the gateway advertises `offline_access` for claude.ai to
  stay logged in. If claude.ai doesn't ask for it, people will have to reconnect often, and we'll need to look at
  session lengths for this client.
- agentgateway fetches Keycloak's keys when it starts, in-cluster, so it doesn't start while Keycloak is down.
- agentgateway's config has changed between minor releases (it ships a `migrate` command for deprecated fields), so
  its chart is kept out of the weekly Platform bundle for minor updates, as in
  [ADR 004](./004-bundle-renovate-updates-weekly.md). Check the config still validates before merging one.
