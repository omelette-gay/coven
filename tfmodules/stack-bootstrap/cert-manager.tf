module "cert_manager" {
  source = "../cert-manager"

  namespace = var.namespaces.cert_manager

  acme_email         = "acme@${var.cluster_domain}"
  letsencrypt_server = var.letsencrypt_server

  depends_on = [helm_release.prometheus_operator_crds]
}
