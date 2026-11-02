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
  version          = var.chart_version

  values = var.values

  depends_on = [module.secret_store]
}
