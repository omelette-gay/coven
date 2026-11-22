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
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}

locals {
  grafana_host  = "monitoring.${var.cluster_domain}"
  vault_host    = "vault.${var.cluster_domain}"
  keycloak_host = "auth.${var.cluster_domain}"
  keycloak_url  = "https://${local.keycloak_host}/auth"

  # outbound mail is installed by platform, but its address is fixed
  smtp_relay = "mail.mail.svc.cluster.local:587"

  # Longhorn volumes with these labels are backed up off-site by the recurring job platform creates
  longhorn_recurring_job_name = "nightly-backup"
  longhorn_backup_labels = {
    "recurring-job.longhorn.io/source"                               = "enabled"
    "recurring-job.longhorn.io/${local.longhorn_recurring_job_name}" = "enabled"
  }
}
