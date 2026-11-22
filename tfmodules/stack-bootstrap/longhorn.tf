module "longhorn" {
  source = "../longhorn"

  namespace                 = var.namespaces.longhorn
  backup_bucket             = var.backup_bucket
  backup_credentials_secret = var.longhorn_backup_credentials_secret

  monitoring_namespace         = kubernetes_namespace_v1.monitoring.metadata[0].name
  over_provisioning_percentage = var.longhorn_over_provisioning_percentage
  allow_degraded_volumes       = var.longhorn_allow_degraded_volumes

  # its ServiceMonitor needs the CRDs
  depends_on = [helm_release.prometheus_operator_crds]
}
