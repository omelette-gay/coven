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
  `gs://<backup_bucket><backup_path>`. Each environment needs its own `backup_path`. See
  [backups and recovery](../../docs/backups-and-recovery.md).
- **Attachments:** the `vikunja-files` volume is labelled for the Longhorn recurring job in
  `longhorn_recurring_job_name`.

## Rotating secrets

- **Keycloak client secret:** increase `keycloak_secret_revision` by one. It writes a new secret to Keycloak and the
  `vikunja-oidc` Secret, and changes a pod annotation so Vikunja restarts and reads it.
- **`service.secret`:** this signs login sessions. It's generated into Vault at `vikunja/service-secret`; increase the
  `service_secret` module's `revision` and restart Vikunja. Everyone is logged out.

## MCP

Vikunja 2.8 has an MCP server at `/api/v2/mcp`, using per-user API tokens with the `mcp:access` scope. Clients that
can send a bearer token (e.g. Claude Code) can use it directly. claude.ai needs OAuth, which Vikunja doesn't do, so
that needs a gateway in front (#592).
