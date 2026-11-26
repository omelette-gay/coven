# GlitchTip

Deploys GlitchTip (error monitoring software).

## Rotating the Keycloak client secret

Increase `keycloak_secret_revision` (`glitchtip_keycloak_secret_revision` in the platform stack) by one. It writes a new
client secret to Keycloak and the `glitchtip-oidc` Secret, then replaces the `glitchtip-configure-oidc` Job so it
copies the new secret into GlitchTip's database. GlitchTip reads it from there, so it needs no restart, and SSO only
fails between the secret changing and the Job finishing.

## Database

GlitchTip's database is a CNPG cluster (`db-cluster`) from the `cluster` chart, taking its image from the shared catalog
(see [ADR 007](../../docs/adr/007-take-postgres-images-from-a-shared-image-catalog.md)).

It replaced the GlitchTip chart's own cluster, `glitchtip-pg`, which couldn't use the catalog (#128). The new cluster was
created by importing the old one's database while GlitchTip was scaled down, and GlitchTip was switched to it in a
separate change, because Helm doesn't wait for the import to finish.

## Backups

With `backup_bucket` set (coven, not the testlab):

- **Database:** the Barman Cloud plugin archives WAL continuously to `gs://<backup_bucket>/cnpg/glitchtip/db-cluster-pg18/`
  and takes a base backup at 09:30 and 21:30. The folder is named after the PostgreSQL major, so it changes with an
  upgrade (see [backups and recovery](../../docs/backups-and-recovery.md#major-upgrades)). It's worth keeping for the
  projects' DSNs, alert rules and issue states more than the events: losing the projects would mean giving every app
  a new DSN.
- **Uploaded files** (RustFS, e.g. source maps): the `glitchtip-rustfs-data` PVC is labelled for the Longhorn
  `longhorn_recurring_job_name` job. The label is added to the PVC the RustFS chart made, rather than by the
  object-store module, which would move RustFS to a new, empty volume.
