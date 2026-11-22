variable "keycloak_bootstrap_admin_password" {
  description = "Only set on platform's first apply on a fresh cluster, before Terraform's own Keycloak user exists: log in as Keycloak's temporary admin with this password instead of the credentials in Vault (see docs/bootstrapping.md). It's only used by the provider, so it isn't stored in state"
  type        = string
  default     = null
  sensitive   = true
}

variable "project_id" {
  description = "The project ID"
  type        = string
  default     = "coven-omelette-gay"
}

terraform {
  required_version = ">= 1.11.0"

  backend "gcs" {
    bucket = "coven-tfstate"
    prefix = "terraform/platform"
  }
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.4"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
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
  }
}

provider "google" {
  project               = var.project_id
  region                = "europe-west2"
  user_project_override = true
  billing_project       = var.project_id
}

provider "vault" {
  address = "https://vault.coven.omelette.gay"
}

ephemeral "vault_kv_secret_v2" "hetzner" {
  mount = "secret"
  name  = "gitops/hetzner"
}

provider "hcloud" {
  token = ephemeral.vault_kv_secret_v2.hetzner.data["api_token"]
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

ephemeral "vault_kv_secret_v2" "keycloak" {
  count = var.keycloak_bootstrap_admin_password == null ? 1 : 0

  mount = "secret"
  name  = "gitops/keycloak-master-credentials"
}

locals {
  keycloak_url       = "https://auth.coven.omelette.gay"
  keycloak_base_path = "/auth"
}

provider "keycloak" {
  url       = local.keycloak_url
  base_path = local.keycloak_base_path
  realm     = "master"
  client_id = "admin-cli"
  username  = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["username"] : "temp-admin"
  password  = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["password"] : var.keycloak_bootstrap_admin_password
}

module "platform" {
  source = "../../tfmodules/stack-platform"

  keycloak_url   = "${local.keycloak_url}${local.keycloak_base_path}"
  cluster_issuer = "letsencrypt"

  glitchtip_domain               = "errors.omelette.gay"
  glitchtip_postgresql_instances = 2
  glitchtip_sender_email         = "glitchtip@coven.omelette.gay"

  # 2 rotates the Keycloak client secret and gives its Secret the standard keys (see tfmodules/keycloak-client)
  glitchtip_keycloak_secret_revision = 2

  cluster_domain     = "coven.omelette.gay"
  keycloak_realm     = "omelette.gay"
  grafana_host       = "monitoring.coven.omelette.gay"
  vault_host         = "vault.coven.omelette.gay"
  kubernetes_api_url = "https://strix.xdc.omelette.gay:6443"

  discord_alerts    = true
  loki_storage_size = "50Gi"

  dns_zone = {
    id   = data.hcloud_zone.omelette_gay.id
    name = data.hcloud_zone.omelette_gay.name
  }
  # strix, which outbound mail runs on
  mail_ipv4_addresses = ["168.119.4.112"]
  outbound_mail_node_selector = {
    "coven.omelette.gay/location" = "xdc"
  }
}
