terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
  }
}

locals {
  ghcr_enabled = var.ghcr_secret_name != null

  # Every namespace that pulls from GHCR has the same names, and the Vault role is per namespace
  ghcr_service_account_name = "ghcr-creds-reader"
  ghcr_vault_role_name      = "${var.name}-ghcr-creds"
}

# A ServiceAccount that Vault trusts to read the shared GHCR credentials, so the namespace can pull private images
resource "kubernetes_service_account_v1" "ghcr_reader" {
  count = local.ghcr_enabled ? 1 : 0

  metadata {
    name      = local.ghcr_service_account_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}

resource "vault_kubernetes_auth_backend_role" "ghcr_reader" {
  count = local.ghcr_enabled ? 1 : 0

  backend                          = "kubernetes"
  role_name                        = local.ghcr_vault_role_name
  bound_service_account_names      = [local.ghcr_service_account_name]
  bound_service_account_namespaces = [kubernetes_namespace_v1.this.metadata[0].name]
  token_policies                   = [var.ghcr_policy_name]
}

resource "kubernetes_manifest" "ghcr_secret_store" {
  count = local.ghcr_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "ghcr"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      provider = {
        vault = {
          server  = var.vault_server
          path    = var.vault_kv_mountpoint
          version = "v2"
          auth = {
            kubernetes = {
              role = local.ghcr_vault_role_name
              serviceAccountRef = {
                name = local.ghcr_service_account_name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account_v1.ghcr_reader,
    vault_kubernetes_auth_backend_role.ghcr_reader
  ]
}

resource "kubernetes_manifest" "ghcr_credentials" {
  count = local.ghcr_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "ghcr-credentials"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "ghcr"
        kind = "SecretStore"
      }
      target = {
        name = var.ghcr_secret_name
        template = {
          type = "kubernetes.io/dockerconfigjson"
          data = {
            # The {{ }} parts are External Secrets templates, filled in from Vault
            ".dockerconfigjson" = chomp(<<-EOT
              { "auths": { "ghcr.io": { "username": "{{ .registryUser }}", "password":"{{ .password }}", "auth": "{{ printf "%s:%s" .registryUser .password | b64enc }}" } } }
            EOT
            )
          }
        }
      }
      data = [
        {
          secretKey = "registryUser"
          remoteRef = {
            key      = var.ghcr_vault_secret_name
            property = "user"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = var.ghcr_vault_secret_name
            property = "password"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.ghcr_secret_store]
}
