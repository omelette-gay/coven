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
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
  }
}

resource "kubernetes_namespace_v1" "external_dns" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

module "hetzner_token" {
  source = "../vault-k8s-secret"

  vault_secret_name             = var.vault_secret_name
  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
  k8s_secret_name               = "hetzner"
  k8s_namespace                 = kubernetes_namespace_v1.external_dns.metadata[0].name
  k8s_service_account_name      = "hetzner-secret-reader"
  vault_role_name               = "hetzner-hetzner"
}

locals {
  # renovate: datasource=docker depName=docker.io/hetzner/external-dns-hetzner-webhook
  webhook_tag = "v0.5.1"
}

resource "helm_release" "external_dns" {
  name       = "hetzner"
  namespace  = kubernetes_namespace_v1.external_dns.metadata[0].name
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.24.0"
  atomic     = true
  wait       = true

  values = [yamlencode({
    policy = "sync"
    provider = {
      name = "webhook"
      webhook = {
        image = {
          repository = "docker.io/hetzner/external-dns-hetzner-webhook"
          tag        = local.webhook_tag
        }
        env = [{
          name = "HETZNER_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = module.hetzner_token.k8s_secret_name
              key  = "api_token"
            }
          }
        }]
      }
    }
    serviceMonitor = { enabled = true }
    # external-dns only changes records whose ownership TXT records carry this
    txtOwnerId = var.txt_owner_id
  })]
}
