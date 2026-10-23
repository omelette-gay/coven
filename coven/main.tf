variable "project_id" {
  description = "The project ID"
  type        = string
  default     = "coven-omelette-gay"
}

terraform {
  backend "gcs" {
    bucket = "coven-tfstate"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.8.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.4.0"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.10.0"
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
  username  = ephemeral.vault_kv_secret_v2.keycloak.data["username"]
  password  = ephemeral.vault_kv_secret_v2.keycloak.data["password"]
}
