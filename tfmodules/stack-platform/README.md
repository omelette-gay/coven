# Platform stack

The content of the platform stack, the second of the three Terraform stacks described in
[ADR 002](../../docs/adr/002-three-stack-terraform-for-cluster-configuration.md). It's called by the thin root modules
in [coven/platform/](../../coven/platform/) and [testlab/platform/](../../testlab/platform/), which set the backend,
providers and variables, and hold resources that only exist in one environment (on coven, the backup service account
keys, the machines' DNS records, and the GitHub Actions role used to deploy self-deploying apps).

Platform configures the services installed by bootstrap (through the `vault` and `keycloak` providers), and installs
services that apps depend on. Vault must be unsealed and Keycloak running before it can be planned.

## Layout

- **Here:** Vault's configuration ([vault.tf](./vault.tf): mounts, policies, auth methods including GitHub Actions',
  the Kubernetes secrets engine) and CA ([pki.tf](./pki.tf), with cert-manager's `vault` ClusterIssuer); the Keycloak
  realm, `admins` group and Terraform's own user ([keycloak.tf](./keycloak.tf)); Grafana's SSO client, Discord alerting
  and the blackbox probes ([monitoring.tf](./monitoring.tf)); Longhorn's backup credentials and recurring jobs.
- **Modules:** [glitchtip](../glitchtip/), [logging](../logging/), [external-dns](../external-dns/) (only with a
  `dns_zone`), [outbound-mail](../outbound-mail/) and [mariadb-operator](../mariadb-operator/).

Everything that uses a Vault mount refers to the mount resource (through `local.vault`), so on a fresh cluster it's made
after the mount. The modules take the mount paths as inputs for this. Root modules get the paths from the outputs.

## Conventions

As in bootstrap, every `helm_release` sets `atomic = true`, and names both stacks need are passed in by the root
modules. Secrets are kept out of state where the providers allow it (see [secrets](../../docs/secrets.md)): generated
values are written to Vault write-only and synced by External Secrets Operator. Keycloak client secrets are the
exception, as the provider always reads them back.
