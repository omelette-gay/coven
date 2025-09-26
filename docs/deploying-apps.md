# How to let apps from outside of the repo deploy to the cluster

We want to let apps deploy to this repo in addition to the 3rd party ones that are deployed within this repo. Rather than
define it in this repo, and have to run an entire cluster upgrade to do it, we generally want each app to deploy itself
from its own code and own GitHub Actions on a continuous delivery model.

Vault in the cluster can be configured to trust GitHub tokens for particular repos, and grant access to deploy into a
namespace from that repo. We have a GitHub Action ([vault-k8s-login-action](https://github.com/omelette-gay/vault-k8s-login-action/))
that simplifies logging into the cluster with the GitHub token and obtaining k8s credentials. For an example of this,
have a look at the [deployment action for Chris's Weight Tracker](https://github.com/cnorthwood/chriss-weight-tracker/blob/main/.github/workflows/deploy.yml), which
uses this action, writes out a kubeconfig, and then uses Helm to install to the namespace.

Sometimes the apps we deploy will need some other secrets from the cluster. To simplify the process, you can also specify
in the inventory whether or not secrets should be synced from Vault, whether or not the global GitHub Container Registry
secret should be synced (which will allow pulling from private repos that Chris has access to), and whether or not a
Keycloak client should be created with the secrets written into k8s.

To add a new app, then add the app to the `k8s_github_deployment_roles` list in the inventory, the full set of config options
is specified below:

```yaml
k8s_github_deployment_roles:
  - github_repo: omelette-gay/example-app             # this is the name of the GitHub repo which access is granted to
    k8s_namespace: example-app                        # this is the k8s namespace that the deployment is permitted to access - note that full access is given to this namespace
    role_name: example-app-deployment                 # this is appended to github- as the name of the role within Vault which the vault-k8s-login-action will attempt to log in as, so in this case this will be github-example-app and should be set in the vault-k8s-login-action as vault-k8s-role: github-example-app
    ghcr_credentials_secret: ghcr-credentials         # this is optional, and if set will write the GitHub Container Registry credentials to this secret in a format that is compatible with the imagePullSecrets setting in a k8s pod spec
    vault_secrets:                                    # this is optional, and is a list of secrets to sync from Vault into this namespace
      - vault_secret_name: example-app/config         # this is the name of the secret in Vault
        k8s_secret_name: example-app-secrets          # this is the name of the secret resource that will be created in k8s
        k8s_namespace: example-app                    # this is the namespace the secret is created in (this must be set to the same as above)
        k8s_service_account_name: example-app-secrets # this is the name of the k8s service account that will be created that will be granted access to Vault
        vault_role_name: example-app-secrets          # this is the name of the role within Vault that can read the secret and the k8s service account will be granted access to
    keycloak_client_id: example-app                   # this is optional, and if specified, will create a client within Keycloak that this app can use to authenticate users
    keycloak_redirect_uris:                           # this is required if the keycloak_client_id is set and is the list of redirect URIs that Keycloak will accept for this app
      - https://example.omelette.gay/oidc/callback/
    keycloak_k8s_secret: sso-secrets                  # this is required if the keycloak_client_id is set and is the name of the secret that will be created in k8s containing the OIDC configuration for Keycloak. The secret will have the following keys corresponding to the relevant OIDC config settings for our Keycloak: clientId, clientSecret, authorizationEndpoint, tokenEndpoint, userEndpoint, jwksEndpoint
```

When configuring Keycloak, by default it will map through the client roles through as the roles claim when logging in.
The app is then responsible for reacting appropriately to these roles. In future we should allow the creation of client
roles and mapping of them to groups when configuring an app here, but that is not currently needed so hasn't yet been added.
