terraform {
  backend "gcs" {
    bucket = "coven-tfstate"
    prefix = "terraform/apps"
  }
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
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
  }
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

provider "keycloak" {
  url       = local.keycloak_url
  base_path = local.keycloak_base_path
  realm     = "master"
  client_id = "admin-cli"
  username  = ephemeral.vault_kv_secret_v2.keycloak.data["username"]
  password  = ephemeral.vault_kv_secret_v2.keycloak.data["password"]
}

locals {
  keycloak_url       = "https://auth.coven.omelette.gay"
  keycloak_base_path = "/auth"
  keycloak_realm     = "omelette.gay"

  # The Longhorn recurring job that backs volumes up off-site
  nightly_backup_job = "nightly-backup"

  # Game servers need a datacentre IP, so prefer running them on the xdc node
  game_server_preferred_node = { "coven.omelette.gay/location" = "xdc" }
}
