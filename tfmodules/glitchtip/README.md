# GlitchTip

Deploys GlitchTip (error monitoring software).

## Rotating the Keycloak client secret

Increase `keycloak_secret_revision` (`glitchtip_keycloak_secret_revision` in the platform stack) by one. It writes a new
client secret to Keycloak and the `glitchtip-oidc` Secret, then replaces the `glitchtip-configure-oidc` Job so it
copies the new secret into GlitchTip's database. GlitchTip reads it from there, so it needs no restart, and SSO only
fails between the secret changing and the Job finishing.
