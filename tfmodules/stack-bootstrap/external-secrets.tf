resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "external-secrets"
    }
  }
}

# Syncs secrets from Vault into Kubernetes. It's here rather than in platform because platform creates SecretStores and
# ExternalSecrets with kubernetes_manifest, which needs the CRDs to exist when platform is planned (see ADR 002).
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  repository = "https://charts.external-secrets.io/"
  chart      = "external-secrets"
  version    = "2.15.0"
  atomic     = true
  wait       = true

  values = [yamlencode({
    serviceMonitor = { enabled = true }
    webhook = {
      serviceMonitor = { enabled = true }
    }
    certController = {
      serviceMonitor = { enabled = true }
    }
  })]

  depends_on = [helm_release.prometheus_operator_crds]
}
