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

The game service is a `LoadBalancer`, and the web interface is exposed through Traefik at `hostname` with a
certificate from `cluster_issuer` (default `letsencrypt`) and an HTTP to HTTPS redirect. CPU and memory requests have
defaults based on observed usage (`cpu_request`, `memory_request`), with no limits.

Anything else, such as the server's config files, goes in `values`. Don't use `templatefile()` on it, as `{{ .server_password }}` is an External Secrets
template, not Terraform or Helm syntax.

The module creates the namespace, so there can only be one instance (one call of this module) per namespace. To run
more than one server, give each its own `namespace`.

The release is `atomic`, so a failed upgrade rolls back. The universe and plugin volumes are labelled with
`longhorn_recurring_job_name` (set it to `nightly-backup` for off-site backups). Deleting the namespace, for example by
removing this module, deletes the volumes along with it, as the `keep` annotation only protects them from a Helm
uninstall. Restore them from the Longhorn backup if that happens (see
[backups and recovery](../../docs/backups-and-recovery.md)).
