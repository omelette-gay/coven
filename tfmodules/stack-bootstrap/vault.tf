module "vault" {
  source = "../vault"

  namespace           = var.namespaces.vault
  host                = var.vault_host
  cluster_issuer      = var.cluster_issuer
  data_storage_labels = local.longhorn_backup_labels
  host_aliases        = var.host_aliases

  # Traefik's config first, as the metrics middleware needs its blockpath plugin
  depends_on = [
    helm_release.prometheus_operator_crds,
    module.longhorn,
    module.cert_manager,
    kubernetes_manifest.traefik_config,
    kubernetes_manifest.redirect_https,
  ]
}
