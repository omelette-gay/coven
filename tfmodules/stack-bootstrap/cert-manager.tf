resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "cert-manager"
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

  depends_on = [helm_release.prometheus_operator_crds]
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
    email  = "acme@${var.cluster_domain}"
    server = var.letsencrypt_server
  })]

  # created by Ansible before this release existed
  take_ownership = true

  depends_on = [helm_release.cert_manager]
}

# Redirects HTTP to HTTPS, for every ingress to use. Traefik's CRDs come with k3s.
resource "kubernetes_manifest" "redirect_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "redirect-https"
      namespace = "kube-system"
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }
}
