terraform {
  required_version = ">= 1.11.0"

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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}

locals {
  # namespaces the bootstrap stack makes
  namespaces = {
    monitoring   = "monitoring"
    keycloak     = "keycloak"
    vault        = "vault"
    longhorn     = "longhorn-system"
    cert_manager = "cert-manager"
  }

  # the blackbox exporter bootstrap installs, which probes our sites from inside the cluster
  blackbox_prober = {
    url  = "blackbox-exporter-prometheus-blackbox-exporter.${local.namespaces.monitoring}.svc.cluster.local:9115"
    path = "/probe"
  }

  # Vault's mounts, so that everything using them is made after them on a fresh cluster
  vault = {
    kv_mountpoint           = vault_mount.secret.path
    kubernetes_auth_backend = vault_auth_backend.kubernetes.path
  }
}
