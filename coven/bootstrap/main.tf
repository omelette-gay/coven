variable "keycloak_bootstrap_admin_password" {
  description = "Only set on the first apply of a fresh cluster, e.g. with TF_VAR_keycloak_bootstrap_admin_password (see docs/bootstrapping.md)"
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
    prefix = "terraform/bootstrap"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

provider "google" {
  project               = var.project_id
  region                = "europe-west2"
  user_project_override = true
  billing_project       = var.project_id
}

# bootstrap can't use Vault, as it runs before Vault is set up, so the token comes from the HCLOUD_TOKEN environment
# variable
provider "hcloud" {}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "bootstrap" {
  source = "../../tfmodules/stack-bootstrap"

  cluster_domain     = "coven.omelette.gay"
  cluster_issuer     = "letsencrypt"
  letsencrypt_server = "https://acme-v02.api.letsencrypt.org/directory"

  keycloak_bootstrap_admin_password = var.keycloak_bootstrap_admin_password
}
