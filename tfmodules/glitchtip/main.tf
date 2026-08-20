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
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "glitchtip"
  }
}

module "secret" {
  source = "../vault-k8s-secret"

  vault_secret_name        = "glitchtip/app"
  k8s_secret_name          = "glitchtip-secrets"
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "glitchtip-secrets"
  vault_role_name          = "glitchtip"

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "this" {
  name          = "glitchtip"
  namespace     = kubernetes_namespace_v1.this.metadata[0].name
  repository    = "https://gitlab.com/api/v4/projects/16325141/packages/helm/stable"
  chart         = "glitchtip"
  version       = "9.0.1"
  timeout       = 900
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      glitchtip = {
        existingSecret = "glitchtip-secrets"
        domain         = "https://${var.domain}"
      }

      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
          "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd"
        }
        hosts = [{
          host = var.domain
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }]
        tls = [{
          hosts      = [var.domain]
          secretName = "glitchtip-tls"
        }]
      }

      monitoring = {
        enabled = true
      }

      valkey = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      postgresql = {
        enabled = true
        cluster = {
          instances = var.postgresql_instances
          storage = {
            size = var.postgresql_storage_size
          }
          monitoring = {
            enabled = true
          }
        }
      }
    })
  ]

  depends_on = [module.secret]
}

resource "kubernetes_manifest" "probe" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "glitchtip-https"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober = {
        url  = "blackbox-exporter-prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115"
        path = "/probe"
      }
      targets = {
        staticConfig = {
          static = ["https://${var.domain}/"]
        }
      }
    }
  }

  depends_on = [helm_release.this]
}
