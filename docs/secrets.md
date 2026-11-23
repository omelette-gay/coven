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
This repository's own CI is admin, so only some of its workflows can log in: see
[CI and its credentials](./cluster-overview.md#ci-and-its-credentials).

To follow the principle of least responsibility, each machine user should be created with a policy that limits it to
only the secrets it needs.

Furthermore, we want to be able to authenticate into the k8s cluster to run commands remotely. Vault can also be
set up as a trusted issuer of tokens within k8s, as well as trusting k8s tokens. This means human users and non-k8s
machine users can request k8s auth tokens from Vault to let them run `kubectl` and other commands remotely.

The final piece of the puzzle is providing Vault secrets to k8s apps at run time. [External Secrets Operator](https://external-secrets.io/)
can be used to do this. This will create/update k8s secrets and populate them with the contents of secrets within
Vault. These k8s secrets can then be specified as required either as environment variable sources, or in Helm charts,
where a secret is needed.

## Secrets and Terraform state

Terraform state is stored in the `coven-tfstate` bucket, which is treated as sensitive, but **we want as few secrets in
it as possible**. Anyone who can read the state can read what's in it, and the bucket keeps old versions of it.

- **Generate secrets with an `ephemeral` resource** (`ephemeral "random_password"`), never a plain `random_password`,
  which stores its value in state.
- **For a secret nobody needs to know** (a password between two of our own services, a signing key), **use the
  [generated-secret](../tfmodules/generated-secret/) module.** It generates the values, writes them to Vault with a
  write-only argument (`data_json_wo` on `vault_kv_secret_v2`, which the provider doesn't read back), and has External
  Secrets Operator create the Kubernetes Secret, using [vault-k8s-secret](../tfmodules/vault-k8s-secret/) for the sync.
  Terraform then never manages the Kubernetes Secret, and the secret isn't in state.
- **Don't write secrets into a `kubernetes_secret_v1`**, even with `data_wo`. Write-only arguments only keep the value
  in our configuration out of state: the provider still reads the Secret's `data` back into it.

**The exception is Keycloak client secrets**, which can't be kept out of state. The `keycloak_openid_client` resource
reads the client's secret back into state even when it was set with `client_secret_wo`, so the same value is in state
whatever we do with the Kubernetes copy. The [keycloak-client](../tfmodules/keycloak-client/) module writes its Secret
with `kubernetes_secret_v1` for that reason: moving it to Vault wouldn't remove the secret from state.

## Google Cloud access from the cluster

**Don't give pods Google service account keys where we can avoid it.** Let them act as the service account through
workload identity federation instead, so there's no key to store, leak or rotate:

- The cluster's workload identity pool is in the bootstrap stack
  ([coven/bootstrap/workloadidentity.tf](../coven/bootstrap/workloadidentity.tf)). GCP checks tokens for Kubernetes
  service accounts against the cluster's public signing keys, which Terraform reads from the cluster with `kubectl`.
  CI can't change workload identity pools ([ADR 006](./adr/006-gate-ci-credentials-by-workflow-and-environment.md)), so
  after a cluster rebuild changes the keys, a project owner applies bootstrap from their own machine before CI's next
  apply.
- The [gcp-workload-identity](../tfmodules/gcp-workload-identity/) module lets one Kubernetes service account act as
  one GCP service account, in any project, and gives the pods a credentials file with nothing secret in it. See the
  weight tracker in [coven/apps/weight-tracker.tf](../coven/apps/weight-tracker.tf).

This needs software that uses Google's client libraries. Some software signs its own tokens with a key's private key
(Home Assistant's Google Assistant integration does), and Longhorn needs HMAC keys for the S3 API, so those still need
keys.

Apps that need their own GCP project (for an OAuth client, say) have it managed in the apps stack. CI is given access
to each one in the bootstrap stack ([coven/bootstrap/githubactions.tf](../coven/bootstrap/githubactions.tf)): add the
project ID to `app_gcp_projects`, and a project owner applies that once from their own machine, since CI can't grant
itself access. Owners, OAuth clients and consent screens can't be managed with Terraform, so are set up by hand.
