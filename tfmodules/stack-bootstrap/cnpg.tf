module "cnpg" {
  source = "../cnpg"

  namespace          = var.namespaces.cnpg
  image_catalog_name = var.postgresql_image_catalog

  # the barman-cloud plugin's webhook certificate comes from cert-manager
  depends_on = [helm_release.prometheus_operator_crds, module.cert_manager]
}
