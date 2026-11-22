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

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io/"
  chart      = "cert-manager"
  version    = "v1.21.3"
  atomic     = true
  wait       = true

  values = [yamlencode({
    crds = { enabled = true }
    prometheus = {
      enabled        = true
      servicemonitor = { enabled = true }
    }
  })]
}

# The Let's Encrypt ClusterIssuer. Its CRD comes from cert-manager above, so it's made through a small local chart rather
# than kubernetes_manifest, which would need the CRD to exist when this stack is planned (see ADR 002). The Vault
# ClusterIssuer is made by platform, as it needs Vault configured.
resource "helm_release" "letsencrypt_issuer" {
  name      = "letsencrypt-issuer"
  namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  chart     = "${path.module}/charts/letsencrypt-issuer"
  atomic    = true
  wait      = true

  values = [yamlencode({
    email  = var.acme_email
    server = var.letsencrypt_server
  })]

  # created by Ansible before this release existed
  take_ownership = true

  depends_on = [helm_release.cert_manager]
}
