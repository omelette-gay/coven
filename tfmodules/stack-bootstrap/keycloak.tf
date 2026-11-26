module "keycloak" {
  source = "../keycloak"

  namespace                 = var.namespaces.keycloak
  url                       = var.keycloak_url
  cluster_issuer            = var.cluster_issuer
  backup_bucket             = var.backup_bucket
  postgresql_image_catalog  = var.postgresql_image_catalog
  backup_credentials_secret = var.keycloak_backup_credentials_secret
  bootstrap_admin_username  = var.keycloak_bootstrap_admin_username
  bootstrap_admin_password  = var.keycloak_bootstrap_admin_password

  # Longhorn first, so the database's volumes get its storage class
  depends_on = [
    helm_release.prometheus_operator_crds,
    module.longhorn,
    module.cnpg,
    module.cert_manager,
    kubernetes_manifest.redirect_https,
  ]
}
