# cert-manager

Installs [cert-manager](https://cert-manager.io/) and the `letsencrypt` ClusterIssuer. Called by the bootstrap stack.

The ClusterIssuer is in a small local chart ([charts/letsencrypt-issuer](./charts/letsencrypt-issuer/)) rather than a
`kubernetes_manifest`, so it can be created in the same apply as cert-manager, whose CRD it needs (see ADR 002). The
`vault` ClusterIssuer is made by the platform stack, as it needs Vault configured.

`letsencrypt_server` defaults to Let's Encrypt's staging server, so only coven uses up real rate limits.

Terraform only notices changes to the local chart's values or its `Chart.yaml` version, so after editing its templates,
increase the version in `Chart.yaml`.
