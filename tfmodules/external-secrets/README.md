# External Secrets Operator

Installs [External Secrets Operator](https://external-secrets.io/), which syncs secrets from Vault into Kubernetes
Secrets. Called by the bootstrap stack, rather than platform, because platform creates SecretStores and ExternalSecrets
with `kubernetes_manifest`, which needs their CRDs to exist when platform is planned (see ADR 002). The
[vault-k8s-secret](../vault-k8s-secret/) module sets up each sync.
