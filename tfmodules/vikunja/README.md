# Vikunja

Deploys [Vikunja](https://vikunja.io/) (task lists and kanban boards) with the official chart, a CNPG Postgres
cluster backed up to GCS, and Keycloak SSO.

## SSO

Logging in is only through Keycloak (`auth.local.enabled: false`, registration off). Vikunja can't require a role or
group claim, so anyone in the realm can log in and gets their own account, which can create projects but sees nobody
else's unless they're shared with it. See [single sign-on](../../docs/sso.md).

Accounts are linked to Keycloak by issuer and `sub`, not email, so changing someone's email in Keycloak doesn't move
or take over an account.

## Backups

- **Database:** the CNPG Barman Cloud plugin archives WAL continuously and takes a base backup at 09:00 and 21:00 to
  `gs://<backup_bucket><backup_path>` (`/cnpg/<namespace>/` by default). Each environment needs its own
  `backup_path`. See [backups and recovery](../../docs/backups-and-recovery.md).
- **Attachments:** these are stored in the `vikunja` bucket of a RustFS object store in the namespace (the
  [object-store](../object-store/) module). RustFS's volume is backed up by the Longhorn recurring job in
  `longhorn_recurring_job_name`, which has to be set before first deploying.

## Running more than one copy

Vikunja runs as a single pod; only the database has a standby. Keeping files in RustFS means the app has no volume
of its own, but more replicas still wouldn't work: every copy runs the scheduled jobs (reminder and overdue emails,
webhooks) with no locking, so each would be sent once per pod, and the cache and rate limits are in memory unless
Redis is configured. RustFS itself is also a single pod.

## Rotating secrets

- **Keycloak client secret:** increase `keycloak_secret_revision` by one. It writes a new secret to Keycloak and the
  `vikunja-oidc` Secret, and changes a pod annotation so Vikunja restarts and reads it.
- **`service.secret`:** this signs login sessions. It's generated into Vault at `<namespace>/service-secret`
  (`vikunja/service-secret` by default); increase the `service_secret` module's `revision` and restart Vikunja.
  Everyone is logged out.

## MCP

Vikunja 2.8 has an MCP server at `/api/v2/mcp`, which only takes Vikunja API tokens with the `mcp:access` scope.
claude.ai's custom connectors need OAuth, so an [agentgateway](../agentgateway/) in the namespace takes over that path
(and its OAuth metadata), and everything else on the host still goes to Vikunja. See
[ADR 008](../../docs/adr/008-put-an-oauth-gateway-in-front-of-vikunjas-mcp-server.md).

- MCP clients log in through Keycloak with the `vikunja-mcp` client, whose access tokens carry the person's
  `vikunja_mcp_token` user attribute and have the MCP endpoint's URL as their audience. The gateway swaps the access
  token for that Vikunja token, so Vikunja checks that person's own permissions.
- The attribute is added to the realm's user profile by the platform stack
  (`tfmodules/stack-platform/keycloak-user-profile.tf`).
- Only claude.ai can log in: the client only allows its callback addresses. Vikunja API tokens are no longer accepted
  at `/api/v2/mcp`, so other MCP clients such as Claude Code can't use it. The rest of the API (`/api/v1`) still takes
  them.

### Setting it up for someone

See [letting Claude use Vikunja](../../docs/sso.md#letting-claude-use-vikunja): each person creates a Vikunja token
without delete permissions, pastes it on their Keycloak account page, and adds claude.ai's connector with the client
ID and secret from the `vikunja-mcp-oidc` Secret.

### Rotating the MCP client secret

Increase `mcp_keycloak_secret_revision` by one. It writes a new secret to Keycloak and the `vikunja-mcp-oidc` Secret.
claude.ai keeps its own copy, so each connector has to be updated with the new secret.
