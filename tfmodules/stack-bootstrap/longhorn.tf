module "longhorn" {
  source = "../longhorn"

  monitoring_namespace         = kubernetes_namespace_v1.monitoring.metadata[0].name
  over_provisioning_percentage = var.longhorn_over_provisioning_percentage
  allow_degraded_volumes       = var.longhorn_allow_degraded_volumes

  # its ServiceMonitor needs the CRDs
  depends_on = [helm_release.prometheus_operator_crds]
}
