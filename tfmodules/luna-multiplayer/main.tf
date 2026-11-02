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

# The chart creates its own ExternalSecret to render the server config with secrets from Vault, but it needs a
# SecretStore in the namespace to read from
module "secret_store" {
  source = "../vault-k8s-secret"

  create_external_secret   = false
  vault_secret_name        = var.vault_secret_name
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "${var.namespace}-${var.instance_name}-config"
  vault_role_name          = "${var.namespace}-${var.instance_name}-config"
}

resource "helm_release" "this" {
  name             = var.instance_name
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  create_namespace = false
  repository       = "https://omelette-gay.github.io/luna-multiplayer-helm-chart"
  chart            = "luna-multiplayer"
  version          = "1.0.0"

  values = concat(
    [
      yamlencode({
        # Pinned by digest, which Renovate keeps up to date. Upstream only publishes `master` (a moving tag) and a few
        # release tags, and the running build doesn't match any release tag, so we track master.
        image = {
          # renovate: datasource=docker depName=ghcr.io/lunamultiplayer/lunamultiplayer/server
          tag        = "master@sha256:b03d14534d94f832e2adf2c3735deff4840b58a1dbf7df2e54bdce49e5883c82"
          pullPolicy = "IfNotPresent"
        }

        # Make the chart's ExternalSecret read the server password from the SecretStore made above
        storage = {
          mergeConfigFromExternalSecret = {
            secretStore = module.secret_store.secret_store_name
            remoteKey   = var.vault_secret_name
            keys        = ["server_password"]
          }
        }
      })
    ],
    var.values
  )

  depends_on = [module.secret_store]
}
