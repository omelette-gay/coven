resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = "vault"
    # set by Ansible on coven, kept so the import doesn't change it
    labels = {
      name = "vault"
    }
  }
}

# Hides Vault's metrics from the web. Prometheus scrapes them inside the cluster.
resource "kubernetes_manifest" "vault_block_metrics_path" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "block-metrics-path"
      namespace = kubernetes_namespace_v1.vault.metadata[0].name
    }
    spec = {
      plugin = {
        plugin-blockpath = {
          Regex = ["^/v1/sys/metrics(.*)"]
        }
      }
    }
  }
}

# Vault is configured by platform, through the vault provider, once it's been initialised and unsealed by hand. The chart
# doesn't restart Vault's pod when it's upgraded, so upgrades don't seal it: that only happens when the pod next restarts.
resource "helm_release" "vault" {
  name       = "vault"
  namespace  = kubernetes_namespace_v1.vault.metadata[0].name
  repository = "https://helm.releases.hashicorp.com/"
  chart      = "vault"
  version    = "0.34.1"
  atomic     = true
  wait       = true

  values = [yamlencode({
    global = {
      serverTelemetry = { prometheusOperator = true }
    }
    server = merge(
      {
        ingress = {
          enabled = true
          hosts   = [{ host = local.vault_host }]
          annotations = {
            "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
            "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd,vault-block-metrics-path@kubernetescrd"
          }
          tls = [{
            hosts      = [local.vault_host]
            secretName = "vault-tls"
          }]
        }
        dataStorage = {
          labels = local.longhorn_backup_labels
        }
        standalone = {
          config = <<-EOT
            ui = true

            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"

              # Enable unauthenticated metrics access (necessary for Prometheus Operator)
              telemetry {
                unauthenticated_metrics_access = "true"
              }
            }

            telemetry {
              prometheus_retention_time = "30s",
              disable_hostname = true
            }

            storage "file" {
              path = "/vault/data"
            }
          EOT
        }
      },
      length(var.host_aliases) > 0 ? { hostAliases = var.host_aliases } : {},
    )
    ui = { enabled = true }
    serverTelemetry = {
      serviceMonitor  = { enabled = true }
      prometheusRules = { enabled = true }
    }
  })]

  depends_on = [
    helm_release.prometheus_operator_crds,
    helm_release.longhorn,
    helm_release.cert_manager,
    kubernetes_manifest.redirect_https,
    kubernetes_manifest.vault_block_metrics_path,
  ]
}
