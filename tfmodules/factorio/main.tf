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
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
  }
}

locals {
  password_secret_name = "game-password"

  # Renovate only proposes stable-x.y.z tags (see .github/renovate.json), so experimental releases are skipped
  # renovate: datasource=docker depName=factoriotools/factorio
  image_tag = "stable-2.1.24"
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "factorio-${var.server_id}"
  }
}

module "game_password" {
  source = "../vault-k8s-secret"
  count  = var.password_protected ? 1 : 0

  vault_secret_name        = "factorio/${var.server_id}"
  k8s_secret_name          = local.password_secret_name
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "secret-reader"
  vault_role_name          = "factorio-${var.server_id}"
}

resource "helm_release" "factorio" {
  name       = var.server_id
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://sqljames.github.io/factorio-server-charts/"
  chart      = "factorio-server-charts"
  version    = "2.5.2"
  atomic     = true

  values = [
    yamlencode({
      hostNetworkEnabled = false
      image = {
        tag        = local.image_tag
        pullPolicy = "IfNotPresent"
      }

      service = {
        type           = "LoadBalancer"
        ipFamilyPolicy = "PreferDualStack"
        port           = var.port
        annotations = var.dns == null ? {} : {
          "external-dns.kubernetes.io/hostname" = "factorio-svc.${var.dns.hostname}"
        }
      }

      factorioServer = {
        save_name        = var.save_name
        enable_space_age = var.enable_space_age
      }

      serverPassword = var.password_protected ? {
        passwordSecret = local.password_secret_name
      } : {}

      server_settings = {
        name                = var.server_name
        description         = var.description
        non_blocking_saving = true
        visibility = {
          lan = false
        }
      }

      rcon = {
        external = false
      }
    })
  ]
}

resource "hcloud_zone_rrset" "srv" {
  count = var.dns == null ? 0 : 1

  name = trimsuffix("_factorio._udp.${trimsuffix(var.dns.hostname, var.dns.zone.name)}", ".")
  type = "SRV"
  zone = var.dns.zone.id
  records = [
    {
      value = "0 0 ${var.port} factorio-svc.${var.dns.hostname}."
    }
  ]
}
