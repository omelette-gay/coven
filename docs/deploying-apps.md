# How to let apps from outside of the repo deploy to the cluster

We want to let apps deploy to this repo in addition to the 3rd party ones that are deployed within this repo. Rather than
define it in this repo, and have to run an entire cluster upgrade to do it, we generally want each app to deploy itself
from its own code and own GitHub Actions on a continuous delivery model.

Vault in the cluster can be configured to trust GitHub tokens for particular repos, and grant access to deploy into a
namespace from that repo. We have a GitHub Action ([vault-k8s-login-action](https://github.com/omelette-gay/vault-k8s-login-action/))
that simplifies logging into the cluster with the GitHub token and obtaining k8s credentials. For an example of this,
have a look at the [deployment action for Chris's Weight Tracker](https://github.com/cnorthwood/chriss-weight-tracker/blob/main/.github/workflows/deploy.yml), which
uses this action, writes out a kubeconfig, and then uses Helm to install to the namespace.

Sometimes the apps we deploy will need some other secrets from the cluster. To simplify the process, this repo can also
sync secrets from Vault into the namespace, sync the global GitHub Container Registry secret (which allows pulling from
private repos that Chris has access to), and create a Keycloak client with its credentials written into k8s.

## Adding an app

Each app has a file in [coven/apps/](../coven/apps/) that composes the modules it needs. Copy a similar app's file, such as
[wedding.tf](../coven/apps/wedding.tf) (which uses all of them) or [moretobooks.tf](../coven/apps/moretobooks.tf) (the
smallest). The modules are in [tfmodules/](../tfmodules/):

| Module | Use it for |
|---|---|
| [app-namespace](../tfmodules/app-namespace/) | The namespace, and optionally the GHCR pull secret. One per namespace |
| [github-deployment-role](../tfmodules/github-deployment-role/) | Letting a GitHub repo deploy to the namespace. One per repo, so several repos can share a namespace |
| [vault-k8s-secret](../tfmodules/vault-k8s-secret/) | Syncing a Vault secret into the namespace as a Kubernetes Secret. One per secret |
| [keycloak-client](../tfmodules/keycloak-client/) | A Keycloak client for the app to authenticate users with. Read [single sign-on](./sso.md) first |

```hcl
module "example_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "example-app"
  ghcr_secret_name = "ghcr-credentials"           # optional: creates this Secret for imagePullSecrets
}

module "example_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "omelette-gay/example-app"      # the GitHub repo that's allowed to deploy
  role_name     = "example-app"                   # logged in to as github-example-app, so set vault-k8s-role: github-example-app in the action
  k8s_namespace = module.example_namespace.name   # full access is given to this namespace
}

module "example_secret" {                        # optional, once per secret
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "example-app/config" # the secret in Vault, which you create yourself
  k8s_secret_name          = "example-app-secrets"
  k8s_namespace            = module.example_namespace.name
  k8s_service_account_name = "example-app-secrets"
  vault_role_name          = "example-app-secrets"
}

module "example_sso" {                            # optional
  source = "../../tfmodules/keycloak-client"

  keycloak_url        = "${local.keycloak_url}${local.keycloak_base_path}"
  keycloak_realm      = local.keycloak_realm
  client_id           = "example-app"
  client_name         = "Example"
  valid_redirect_uris = ["https://example.omelette.gay/oidc/callback/"]
  client_roles        = ["admin"]                 # optional
  role_groups         = { admin = ["admins"] }    # optional: grant a role to existing groups
  k8s_namespace       = module.example_namespace.name
  k8s_secret_name     = "sso-secrets"
}
```

The values in Vault aren't in the repo: write them with the Vault UI or CLI before the app uses them.

The Keycloak client's Secret has the same keys for every app: `client_id`, `client_secret`, `authorization_endpoint`,
`token_endpoint`, `userinfo_endpoint` and `jwks_endpoint` (see the [module](../tfmodules/keycloak-client/)). The client's
roles are passed through as the `roles` claim when logging in, and the app is responsible for reacting appropriately to
them. `role_groups` grants roles to groups that already exist; it doesn't manage the groups or who's in them (tracked in
#140). Any user in the realm can log in to any client, so read [single sign-on](./sso.md) before adding a Keycloak
client to an app.

Like every other change, it's applied when it's merged to `main` (see the [cluster overview](./cluster-overview.md)).

## PostgreSQL databases

Apps that need PostgreSQL install their own CloudNativePG cluster with the
[`cluster` chart](https://github.com/cloudnative-pg/charts/tree/main/charts/cluster), usually as a subchart. Take the
image from the shared `postgresql` ClusterImageCatalog (see [ADR 007](./adr/007-take-postgres-images-from-a-shared-image-catalog.md))
rather than setting an image, and set only the major version:

```yaml
version:
  postgresql: "18"
cluster:
  imageCatalogRef:
    kind: ClusterImageCatalog
    name: postgresql
```

The catalog is updated weekly through this repo's Renovate pull requests, and the operator then rolls the database to
the new image on its own, with a switchover. Apps don't need any extra permissions to use it.

- Use the newest major in the catalog for a new database. Older majors drop out of the catalog after they're end of
  life, and a cluster whose major isn't in the catalog stops being reconciled.
- Changing `version.postgresql` to a newer major upgrades the database in place when the app next deploys. Test it on a
  copy first, and make sure a recent backup exists.
- The chart truncates `version.postgresql` to the major, so `"18.4"` still means the latest 18.x in the catalog. If you
  really need a specific minor version, set a digest-pinned `cluster.imageName` instead, but then nothing updates it.
- Every database here uses `C` collation, the chart's default. Keep it: the catalog's minimal images have no other
  locales.
