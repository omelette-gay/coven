terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.10.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.2"
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

provider "vault" {
  address         = "https://vault.coven.local"
  skip_tls_verify = true
}

ephemeral "vault_kv_secret_v2" "keycloak" {
  mount = "secret"
  name  = "gitops/keycloak-master-credentials"
}

provider "keycloak" {
  url                      = "https://auth.coven.local"
  base_path                = "/auth"
  realm                    = "master"
  client_id                = "admin-cli"
  username                 = ephemeral.vault_kv_secret_v2.keycloak.data["username"]
  password                 = ephemeral.vault_kv_secret_v2.keycloak.data["password"]
  tls_insecure_skip_verify = true
}
