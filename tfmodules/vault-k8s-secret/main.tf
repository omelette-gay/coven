terraform {
  # Validation rules that refer to other variables need 1.9
  required_version = ">= 1.9.0"

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

resource "kubernetes_service_account_v1" "reader" {
  metadata {
    name      = var.k8s_service_account_name
    namespace = var.k8s_namespace
  }
}

resource "vault_policy" "reader" {
  name = var.vault_role_name

  policy = <<-EOT
    path "${var.vault_kv_mountpoint}/data/${var.vault_secret_name}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "reader" {
  backend                          = "kubernetes"
  role_name                        = var.vault_role_name
  bound_service_account_names      = [var.k8s_service_account_name]
  bound_service_account_namespaces = [var.k8s_namespace]
  token_policies                   = [vault_policy.reader.name]
}

resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "vault-${var.vault_role_name}"
      namespace = var.k8s_namespace
    }
    spec = {
      provider = {
        vault = {
          server  = var.vault_server
          path    = var.vault_kv_mountpoint
          version = "v2"
          auth = {
            kubernetes = {
              role = var.vault_role_name
              serviceAccountRef = {
                name = var.k8s_service_account_name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account_v1.reader,
    vault_kubernetes_auth_backend_role.reader
  ]
}

resource "kubernetes_manifest" "external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = var.k8s_secret_name
      namespace = var.k8s_namespace
    }
    spec = {
      refreshInterval = var.refresh_interval
      secretStoreRef = {
        name = kubernetes_manifest.secret_store.manifest.metadata.name
        kind = "SecretStore"
      }
      target = {
        name = var.k8s_secret_name
      }
      dataFrom = [{
        extract = {
          key = var.vault_secret_name
        }
      }]
    }
  }
}
