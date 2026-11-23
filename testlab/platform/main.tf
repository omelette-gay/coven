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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
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

# The testlab has no public DNS, so this is never used, but Terraform still configures the provider (for the
# outbound-mail module's DNS records, which the testlab doesn't make) and it won't start without a token
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

# Names the bootstrap and platform stacks share. Keep them the same as in ../bootstrap/main.tf.
locals {
  cluster_domain = "coven.local"
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

  # the testlab doesn't back up
  backup_bucket = null

  # Made by platform, used by bootstrap's services
  longhorn_backup_job_name           = "nightly-backup"
  longhorn_backup_credentials_secret = "gcp-backup-creds"
  keycloak_backup_credentials_secret = "keycloak-gcp-backup-creds"
  grafana_oauth_secret               = "grafana-keycloak-creds"
}

provider "keycloak" {
  url                      = local.keycloak_server
  base_path                = local.keycloak_base_path
  realm                    = "master"
  client_id                = "admin-cli"
  username                 = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["username"] : local.keycloak_bootstrap_admin_username
  password                 = var.keycloak_bootstrap_admin_password == null ? ephemeral.vault_kv_secret_v2.keycloak[0].data["password"] : var.keycloak_bootstrap_admin_password
  tls_insecure_skip_verify = true
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
  longhorn_backup_credentials_secret = local.longhorn_backup_credentials_secret
  keycloak_backup_credentials_secret = local.keycloak_backup_credentials_secret
  grafana_oauth_secret               = local.grafana_oauth_secret

  cluster_issuer = "vault"

  glitchtip_host                 = "errors.coven.local"
  glitchtip_postgresql_instances = 1
  glitchtip_sender_email         = "glitchtip@coven.local"

  cluster_domain     = local.cluster_domain
  kubernetes_api_url = "https://192.168.57.100:6443"
  insecure_tls       = true

  loki_chunks_cache_memory = 1024

  # 2 after the migration rehearsal left Keycloak with different client secrets to Vault and Grafana: the first apply
  # wrote some of them and then failed (see the Keycloak certificate check in tfmodules/stack-platform/vault.tf), and
  # the second wrote new ones to only the other side
  vault_keycloak_secret_revision   = 2
  grafana_keycloak_secret_revision = 2
}
