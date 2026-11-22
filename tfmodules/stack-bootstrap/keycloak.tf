module "keycloak" {
  source = "../keycloak"

  host                     = var.keycloak_host
  cluster_issuer           = var.cluster_issuer
  bootstrap_admin_password = var.keycloak_bootstrap_admin_password

  depends_on = [
    helm_release.prometheus_operator_crds,
    module.cnpg,
    module.cert_manager,
    kubernetes_manifest.redirect_https,
  ]
}
