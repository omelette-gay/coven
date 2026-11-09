# Luna Multiplayer

Installs a [Luna Multiplayer](https://github.com/LunaMultiplayer/LunaMultiplayer) (Kerbal Space Program) server from the
[luna-multiplayer Helm chart](https://github.com/omelette-gay/luna-multiplayer-helm-chart), which is published to
GitHub Pages and no longer deploys itself.

It creates the namespace, the Helm release, and a Vault-backed External Secrets `SecretStore` named
`vault-<namespace>-<instance_name>-config` that the chart's own `ExternalSecret` reads from. The module sets
`storage.mergeConfigFromExternalSecret` for you, so the server config can use `{{ .server_password }}`, which is read
from the `server_password` key of the Vault secret at `vault_secret_name`.

The chart version is pinned in the module so that Renovate can update it, and all instances move together.

The universe and plugin PVCs are annotated `helm.sh/resource-policy: keep`, so uninstalling the release doesn't delete
the game data.

Anything else goes in `values`. Don't use `templatefile()` on it, as `{{ .server_password }}` is an External Secrets
template, not Terraform or Helm syntax.
