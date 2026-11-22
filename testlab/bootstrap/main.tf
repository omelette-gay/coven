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
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
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

module "bootstrap" {
  source = "../../tfmodules/stack-bootstrap"

  cluster_domain = "coven.local"
  cluster_issuer = "vault"
  # Keycloak's hostname doesn't resolve inside the testlab
  host_aliases = [{
    ip        = "192.168.57.100"
    hostnames = ["auth.coven.local"]
  }]
  longhorn_over_provisioning_percentage = 400
  longhorn_allow_degraded_volumes       = true

  keycloak_bootstrap_admin_password = var.keycloak_bootstrap_admin_password
}
