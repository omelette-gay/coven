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

# Loki keeps logs in a RustFS object store. Its volume isn't backed up, as losing logs is acceptable.
module "object_store" {
  source = "../object-store"

  name         = "loki"
  namespace    = var.namespace
  storage_size = var.storage_size
  buckets      = ["loki-chunks", "loki-ruler", "loki-admin"]

  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.namespace
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "loki"
  version    = "21.2.3"
  atomic     = true
  wait       = true
  timeout    = 600

  values = [templatefile("${path.module}/values/loki.yaml.tftpl", {
    object_store_secret   = module.object_store.credentials_secret_name
    object_store_endpoint = module.object_store.endpoint
    chunks_cache_memory   = var.chunks_cache_memory
  })]
}

# Adds Loki to Grafana, through Grafana's sidecar
resource "kubernetes_config_map_v1" "loki_data_source" {
  metadata {
    name      = "loki-data-source"
    namespace = var.namespace
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-stack-datasource.yaml" = chomp(<<-EOT
      apiVersion: 1
      datasources:
        - name: Loki
          type: loki
          access: proxy
          url: http://loki-gateway
          version: 1
    EOT
    )
  }
}

# Runs on every node, sending pods' logs, the systemd journal and Kubernetes events to Loki
resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.16.0"
  atomic     = true
  wait       = true

  values = [file("${path.module}/values/alloy.yaml")]

  depends_on = [helm_release.loki]
}
