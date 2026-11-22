terraform {
  required_version = ">= 1.11.0"

  required_providers {
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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}

locals {
  # the blackbox exporter bootstrap installs, which probes our sites from inside the cluster
  blackbox_prober = {
    url  = "blackbox-exporter-prometheus-blackbox-exporter.${var.namespaces.monitoring}.svc.cluster.local:9115"
    path = "/probe"
  }

  # Vault's address inside the cluster
  vault_internal_url = "http://vault.${var.namespaces.vault}.svc.cluster.local:8200"

  # Vault's mounts, so that everything using them is made after them on a fresh cluster
  vault = {
    kv_mountpoint           = vault_mount.secret.path
    kubernetes_auth_backend = vault_auth_backend.kubernetes.path
  }
}
