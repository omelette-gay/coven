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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
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

# Names the bootstrap and platform stacks share. Keep them the same as in ../bootstrap/main.tf.
locals {
  cluster_domain = "coven.omelette.gay"
  grafana_host   = "monitoring.${local.cluster_domain}"
  vault_host     = "vault.${local.cluster_domain}"

  keycloak_server    = "https://auth.${local.cluster_domain}"
  keycloak_base_path = "/auth"
  keycloak_url       = "${local.keycloak_server}${local.keycloak_base_path}"
  keycloak_realm     = "omelette.gay"
  # the temporary admin Keycloak creates on a fresh cluster, which platform's first apply logs in as
  keycloak_bootstrap_admin_username = "temp-admin"

  namespaces = {
    monitoring       = "monitoring"
    longhorn         = "longhorn-system"
    cert_manager     = "cert-manager"
    cnpg             = "cnpg-system"
    vault            = "vault"
    external_secrets = "external-secrets"
    keycloak         = "keycloak"
  }

  backup_bucket = "coven-backups"

  # The PostgreSQL image catalog, which the apps stack and self-deploying apps also reference by name
  postgresql_image_catalog = "postgresql"

  # Made by platform, used by bootstrap's services
  longhorn_backup_job_name           = "nightly-backup"
  longhorn_backup_credentials_secret = "gcp-backup-creds"
  keycloak_backup_credentials_secret = "keycloak-gcp-backup-creds"
  grafana_oauth_secret               = "grafana-keycloak-creds"
}

provider "keycloak" {
  url       = local.keycloak_server
  base_path = local.keycloak_base_path
  realm     = "master"
  client_id = "admin-cli"
  username  = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["username"] : local.keycloak_bootstrap_admin_username
  password  = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["password"] : var.keycloak_bootstrap_admin_password
}

module "platform" {
  source = "../../tfmodules/stack-platform"

  keycloak_url                       = local.keycloak_url
  namespaces                         = local.namespaces
  grafana_host                       = local.grafana_host
  vault_host                         = local.vault_host
  keycloak_realm                     = local.keycloak_realm
  backup_bucket                      = local.backup_bucket
  longhorn_backup_job_name           = local.longhorn_backup_job_name
  postgresql_image_catalog           = local.postgresql_image_catalog
  longhorn_backup_credentials_secret = local.longhorn_backup_credentials_secret
  keycloak_backup_credentials_secret = local.keycloak_backup_credentials_secret
  grafana_oauth_secret               = local.grafana_oauth_secret

  cluster_issuer = "letsencrypt"

  glitchtip_host                 = "errors.omelette.gay"
  glitchtip_postgresql_instances = 2
  glitchtip_sender_email         = "glitchtip@coven.omelette.gay"

  # 2 rotates the Keycloak client secret and gives its Secret the standard keys (see tfmodules/keycloak-client)
  glitchtip_keycloak_secret_revision = 2

  cluster_domain     = local.cluster_domain
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
