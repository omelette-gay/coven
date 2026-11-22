module "cnpg" {
  source = "../cnpg"

  # the barman-cloud plugin's webhook certificate comes from cert-manager
  depends_on = [helm_release.prometheus_operator_crds, module.cert_manager]
}
