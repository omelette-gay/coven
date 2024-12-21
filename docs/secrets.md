# Architectural approach for managing secrets

Kubernetes has a Secret object type for containing secrets that are then either loaded into environment variables,
or otherwise read by other k8s services. We also have a need to store other secrets which might be needed within
deployment jobs etc.

[Hashicorp Vault](https://www.vaultproject.io/) is a fully-fledged secrets manager which can also support our
authentication workflows.

Vault can manage/generate many kinds of secrets, but most will be stored as key-value pairs in a particular secret
location. The locations are generally path-based to allow for fine-grained access control to the secrets. For example,
creating a secret in `app/foo` would then mean a policy can be created which gives access to `app/*` for all the secrets
under there, and does not permit access to other secrets.

There are multiple ways to authenticate to Vault. Humans can use Keycloak SSO to log in, but machine users will need
to use alternative ways to log in. Vault will be set up to trust both GitHub and our Kubernetes cluster, as well as
Keycloak, as trusted identity stores. This means that a GitHub access token (for GitHub Actions jobs) can be used
to authenticate to Vault, and k8s service accounts can also be used to connect to Vault to read secrets from it.

To follow the principle of least responsibility, each machine user should be created with a policy that limits it to
only the secrets it needs.

Furthermore, we want to be able to authenticate into the k8s cluster to run commands remotely. Vault can also be
set up as a trusted issuer of tokens within k8s, as well as trusting k8s tokens. This means human users and non-k8s
machine users can request k8s auth tokens from Vault to let them run `kubectl` and other commands remotely.

The final piece of the puzzle is providing Vault secrets to k8s apps at run time. [External Secrets Operator](https://external-secrets.io/)
can be used to do this. This will create/update k8s secrets and populate them with the contents of secrets within
Vault. These k8s secrets can then be specified as required either as environment variable sources, or in Helm charts,
where a secret is needed.
