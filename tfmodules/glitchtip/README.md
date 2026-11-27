# GlitchTip

Deploys GlitchTip (error monitoring software).

## Rotating the Keycloak client secret

Increase `keycloak_secret_revision` (`glitchtip_keycloak_secret_revision` in the platform stack) by one. It writes a new
client secret to Keycloak and the `glitchtip-oidc` Secret, then replaces the `glitchtip-configure-oidc` Job so it
copies the new secret into GlitchTip's database. GlitchTip reads it from there, so it needs no restart, and SSO only
fails between the secret changing and the Job finishing.

## Database

GlitchTip's database is a CNPG cluster (`db-cluster`) from the `cluster` chart, taking its image from the shared catalog
(see [ADR 009](../../docs/adr/009-take-postgres-images-from-a-shared-image-catalog.md)). It isn't backed up.

It replaced the GlitchTip chart's own cluster, `glitchtip-pg`, which couldn't use the catalog (#128). The new cluster was
created by importing the old one's database while GlitchTip was scaled down, and GlitchTip was switched to it in a
separate change, because Helm doesn't wait for the import to finish.
