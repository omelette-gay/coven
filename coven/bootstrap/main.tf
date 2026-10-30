variable "project_id" {
  description = "The project ID"
  type        = string
  default     = "coven-omelette-gay"
}

terraform {
  backend "gcs" {
    bucket = "coven-tfstate"
    prefix = "terraform/bootstrap"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
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
}
