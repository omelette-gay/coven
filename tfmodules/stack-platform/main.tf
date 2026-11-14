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
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.9.0"
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
