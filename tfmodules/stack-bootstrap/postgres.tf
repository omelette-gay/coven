resource "kubernetes_namespace_v1" "cnpg" {
  metadata {
    name = "cnpg-system"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "cnpg-system"
    }
  }
}

# The CloudNativePG operator, which runs every PostgreSQL cluster (each app installs its own with the `cluster` chart)
resource "helm_release" "cnpg" {
  name       = "cnpg"
  namespace  = kubernetes_namespace_v1.cnpg.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.29.2"
  atomic     = true
  wait       = true

  values = [yamlencode({
    monitoring = {
      podMonitorEnabled = true
      grafanaDashboard  = { create = true }
    }
  })]

  depends_on = [helm_release.prometheus_operator_crds]
}

# Lets the PostgreSQL clusters back up to GCS (see docs/backups-and-recovery.md)
resource "helm_release" "plugin_barman_cloud" {
  name       = "plugin-barman-cloud"
  namespace  = kubernetes_namespace_v1.cnpg.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "plugin-barman-cloud"
  version    = "0.9.0"
  atomic     = true
  wait       = true

  # its webhook certificate comes from cert-manager
  depends_on = [helm_release.cnpg, helm_release.cert_manager]
}
