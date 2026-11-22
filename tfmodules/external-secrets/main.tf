terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

# Syncs secrets from Vault into Kubernetes. It's here rather than in platform because platform creates SecretStores and
# ExternalSecrets with kubernetes_manifest, which needs the CRDs to exist when platform is planned (see ADR 002).
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  repository = "https://charts.external-secrets.io"
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
}
