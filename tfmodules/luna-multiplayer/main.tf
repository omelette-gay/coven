terraform {
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

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# The server config goes into a Secret, as it can contain the server password, which is filled in from Vault. The chart
# copies the files in it over its own defaults
module "secret_store" {
  source = "../vault-k8s-secret"

  create_external_secret   = length(var.config) > 0
  k8s_secret_name          = "${var.instance_name}-config"
  template_data            = var.config
  vault_secret_name        = var.vault_secret_name
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "${var.namespace}-${var.instance_name}-config"
  vault_role_name          = "${var.namespace}-${var.instance_name}-config"
}

locals {
  backup_labels = var.longhorn_recurring_job_name != null ? {
    "recurring-job.longhorn.io/source"                             = "enabled"
    "recurring-job.longhorn.io/${var.longhorn_recurring_job_name}" = "enabled"
  } : {}
}

resource "helm_release" "this" {
  name             = var.instance_name
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  create_namespace = false
  repository       = "https://omelette-gay.github.io/luna-multiplayer-helm-chart"
  chart            = "luna-multiplayer"
  version          = "2.0.0"
  atomic           = true

  values = [
    yamlencode({
      # Pinned by digest, which Renovate keeps up to date. Upstream only publishes `master` (a moving tag) and a few
      # release tags, and the running build doesn't match any release tag, so we track master.
      image = {
        # renovate: datasource=docker depName=ghcr.io/lunamultiplayer/lunamultiplayer/server
        tag        = "master@sha256:b03d14534d94f832e2adf2c3735deff4840b58a1dbf7df2e54bdce49e5883c82"
        pullPolicy = "IfNotPresent"
      }

      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
      }

      gameService = {
        type = "LoadBalancer"
      }

      webService = {
        # Without a hostname the ingress is disabled, and the chart ignores the other settings
        ingress = {
          enabled  = var.hostname != null
          hostname = var.hostname
          annotations = var.hostname != null ? {
            "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
            "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd"
          } : null
          tls = var.hostname != null ? [{
            hosts      = [var.hostname]
            secretName = "${var.instance_name}-ingress-tls"
          }] : null
        }
      }

      storage = {
        universe = {
          pvcLabels = local.backup_labels
        }
        plugins = {
          pvcLabels = local.backup_labels
        }
      }

      existingConfigSecret = module.secret_store.k8s_secret_name != null ? module.secret_store.k8s_secret_name : ""

      affinity = length(var.preferred_node_labels) > 0 ? {
        nodeAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [for key, value in var.preferred_node_labels : {
                  key      = key
                  operator = "In"
                  values   = [value]
                }]
              }
            }
          ]
        }
      } : {}
    })
  ]
}
