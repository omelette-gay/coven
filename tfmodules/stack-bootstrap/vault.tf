module "vault" {
  source = "../vault"

  host                = var.vault_host
  cluster_issuer      = var.cluster_issuer
  data_storage_labels = local.longhorn_backup_labels
  host_aliases        = var.host_aliases

  depends_on = [
    helm_release.prometheus_operator_crds,
    module.longhorn,
    module.cert_manager,
    kubernetes_manifest.redirect_https,
  ]
}
