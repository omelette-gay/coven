terraform {
  # Validation rules that refer to other variables need 1.9
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
  }
}

# RustFS's access and secret keys, kept in Vault and synced by External Secrets Operator, so they aren't in Terraform
# state. (The Secret is named differently to the one Terraform used to make, as ESO won't take over an existing Secret.)
module "credentials" {
  source = "../generated-secret"

  keys = {
    RUSTFS_ACCESS_KEY = 32
    RUSTFS_SECRET_KEY = 64
  }
  vault_secret_name        = "object-store/${var.namespace}/${var.name}"
  k8s_secret_name          = "${var.name}-object-store-keys"
  k8s_namespace            = var.namespace
  k8s_service_account_name = "${var.namespace}-${var.name}-object-store"
  vault_role_name          = "${var.namespace}-${var.name}-object-store"
}

resource "helm_release" "this" {
  name             = "${var.name}-rustfs"
  namespace        = var.namespace
  repository       = "https://charts.rustfs.com"
  chart            = "rustfs"
  version          = "1.0.4"
  create_namespace = false
  wait             = true

  values = [
    yamlencode({
      mode = {
        standalone = {
          enabled = true
        }
        distributed = {
          enabled = false
        }
      }

      storageclass = {
        name            = "longhorn"
        dataStorageSize = var.storage_size
      }

      ingress = {
        enabled = false
      }

      secret = {
        existingSecret = module.credentials.k8s_secret_name
      }

      config = {
        rustfs = {
          log_level = "warn"
        }
      }
    })
  ]

}

resource "kubernetes_job_v1" "bucket" {
  for_each = var.buckets

  metadata {
    name      = "create-${var.name}-bucket-${each.key}"
    namespace = var.namespace
  }

  spec {
    backoff_limit = 6

    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name    = "create-bucket"
          image   = "minio/mc:latest"
          command = ["/bin/sh", "-c"]
          args = [<<-SHELL
            set -eu
            mc alias set object-store ${local.endpoint} "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
            mc mb object-store/${each.key} --ignore-existing
          SHELL
          ]

          env {
            name = "RUSTFS_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = module.credentials.k8s_secret_name
                key  = "RUSTFS_ACCESS_KEY"
              }
            }
          }

          env {
            name = "RUSTFS_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = module.credentials.k8s_secret_name
                key  = "RUSTFS_SECRET_KEY"
              }
            }
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "10m"
  }

  depends_on = [helm_release.this]
}
