variable "keycloak_bootstrap_admin_password" {
  description = "Only set on platform's first apply on a fresh cluster, before Terraform's own Keycloak user exists: log in as Keycloak's temporary admin with this password instead of the credentials in Vault (see docs/bootstrapping.md). It's only used by the provider, so it isn't stored in state"
  type        = string
  default     = null
  sensitive   = true
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "local"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "local"
}

provider "hcloud" {
  token = "0000000000000000000000000000000000000000000000000000000000000000"
}

provider "vault" {
  address         = "https://vault.coven.local"
  skip_tls_verify = true
}

ephemeral "vault_kv_secret_v2" "keycloak" {
  count = var.keycloak_bootstrap_admin_password == null ? 1 : 0

  mount = "secret"
  name  = "gitops/keycloak-master-credentials"
}

locals {
  keycloak_url       = "https://auth.coven.local"
  keycloak_base_path = "/auth"
}

provider "keycloak" {
  url                      = local.keycloak_url
  base_path                = local.keycloak_base_path
  realm                    = "master"
  client_id                = "admin-cli"
  username                 = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["username"] : "temp-admin"
  password                 = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["password"] : var.keycloak_bootstrap_admin_password
  tls_insecure_skip_verify = true
}

module "platform" {
  source = "../../tfmodules/stack-platform"

  keycloak_url   = "${local.keycloak_url}${local.keycloak_base_path}"
  cluster_issuer = "vault"

  glitchtip_domain               = "errors.coven.local"
  glitchtip_postgresql_instances = 1
  glitchtip_sender_email         = "glitchtip@coven.local"

  cluster_domain     = "coven.local"
  keycloak_realm     = "omelette.gay"
  grafana_host       = "monitoring.coven.local"
  vault_host         = "vault.coven.local"
  kubernetes_api_url = "https://192.168.57.100:6443"
  insecure_tls       = true

  loki_chunks_cache_memory = 1024
}
