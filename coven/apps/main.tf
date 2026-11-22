terraform {
  required_version = ">= 1.11.0"

  backend "gcs" {
    bucket = "coven-tfstate"
    prefix = "terraform/apps"
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

# Apps that use Google APIs have their own GCP projects. Name the project on each resource; calls are billed to the
# coven project, as in the bootstrap stack, so they work even when an API isn't yet enabled in the app's project.
provider "google" {
  region                = "europe-west2"
  user_project_override = true
  billing_project       = "coven-omelette-gay"
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

  # The cluster's workload identity pool provider, in the platform stack, for the gcp-workload-identity module
  coven_workload_identity_provider = "projects/211831137824/locations/global/workloadIdentityPools/coven/providers/coven-k3s"

  # The Longhorn recurring job that backs volumes up off-site
  nightly_backup_job = "nightly-backup"

  # Outbound mail, installed by the platform stack
  smtp_host = "mail.mail.svc.cluster.local"
  smtp_port = 587

  # The blackbox exporter, installed by the bootstrap stack, which probes sites over HTTPS
  blackbox_prober = {
    url  = "blackbox-exporter-prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115"
    path = "/probe"
  }

  # Game servers need a datacentre IP, so prefer running them on the xdc node
  game_server_preferred_node = { "coven.omelette.gay/location" = "xdc" }
}
