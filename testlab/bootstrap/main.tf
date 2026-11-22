variable "keycloak_bootstrap_admin_password" {
  description = "Only set on the first apply of a fresh cluster, e.g. with TF_VAR_keycloak_bootstrap_admin_password (see docs/bootstrapping.md)"
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

# Names the bootstrap and platform stacks share. Keep them the same as in ../platform/main.tf.
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

module "bootstrap" {
  source = "../../tfmodules/stack-bootstrap"

  cluster_domain = local.cluster_domain
  cluster_issuer = "vault"

  namespaces                         = local.namespaces
  grafana_host                       = local.grafana_host
  vault_host                         = local.vault_host
  keycloak_url                       = local.keycloak_url
  keycloak_realm                     = local.keycloak_realm
  backup_bucket                      = local.backup_bucket
  longhorn_backup_job_name           = local.longhorn_backup_job_name
  longhorn_backup_credentials_secret = local.longhorn_backup_credentials_secret
  keycloak_backup_credentials_secret = local.keycloak_backup_credentials_secret
  grafana_oauth_secret               = local.grafana_oauth_secret
  keycloak_bootstrap_admin_username  = local.keycloak_bootstrap_admin_username

  # outbound mail, which the platform stack installs
  smtp_host = "mail.mail.svc.cluster.local"
  smtp_port = 587

  # Keycloak's certificate comes from Vault's CA, which Grafana doesn't trust
  insecure_tls = true
  # Keycloak's hostname doesn't resolve inside the testlab
  host_aliases = [{
    ip        = "192.168.57.100"
    hostnames = ["auth.coven.local"]
  }]
  longhorn_over_provisioning_percentage = 400
  longhorn_allow_degraded_volumes       = true

  keycloak_bootstrap_admin_password = var.keycloak_bootstrap_admin_password
}
