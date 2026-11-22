# Vault

Installs [Vault](https://www.vaultproject.io/) in standalone mode with file storage on a Longhorn volume, and hides its
metrics endpoint from the web. Called by the bootstrap stack.

Vault is configured by the platform stack, through the vault provider, once it has been initialised and unsealed by hand
(see [bootstrapping](../../docs/bootstrapping.md)). The chart doesn't restart Vault's pod when it's upgraded, so an
upgrade doesn't seal it; that only happens when the pod next restarts. After changing Vault's config, restart it yourself
and unseal it (see the README).
