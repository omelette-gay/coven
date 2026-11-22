terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "cnpg" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
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

  depends_on = [helm_release.cnpg]
}
