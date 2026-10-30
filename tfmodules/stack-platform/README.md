# Platform stack

The content of the platform stack, the second of the three Terraform stacks described in
[ADR 002](../../docs/adr/002-three-stack-terraform-for-cluster-configuration.md). It's called by the thin root modules
in [coven/platform/](../../coven/platform/) and [testlab/platform/](../../testlab/platform/), which set the backend,
providers and variables, and hold resources that only exist in one environment (on coven, the backup service account
keys and the GitHub Actions access to Vault).

Platform configures the services installed by bootstrap (through the `vault` and `keycloak` providers), and installs
services that apps depend on. Vault must be unsealed and Keycloak running before it can be planned.
