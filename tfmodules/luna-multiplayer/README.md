# Luna Multiplayer

Installs a [Luna Multiplayer](https://github.com/LunaMultiplayer/LunaMultiplayer) (Kerbal Space Program) server from the
[luna-multiplayer Helm chart](https://github.com/omelette-gay/luna-multiplayer-helm-chart), which is published to
GitHub Pages and no longer deploys itself.

It creates the namespace, the Helm release, and a Vault-backed External Secrets `SecretStore` named
`vault-<namespace>-<instance_name>-config` that the chart's own `ExternalSecret` reads from (set
`storage.mergeConfigFromExternalSecret.secretStore` in the values to match).

The universe and plugin PVCs are annotated `helm.sh/resource-policy: keep`, so uninstalling the release doesn't delete
the game data.

Values files can contain `{{ .server_password }}`, which is an External Secrets template, so load them with `file()`,
not `templatefile()`.
