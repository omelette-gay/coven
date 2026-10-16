terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}

ephemeral "random_password" "access_key" {
  length  = 32
  special = false
}

ephemeral "random_password" "secret_key" {
  length  = 64
  special = false
}

resource "kubernetes_secret_v1" "credentials" {
  metadata {
    name      = "${var.name}-object-store-credentials"
    namespace = var.namespace
  }

  data_wo = {
    RUSTFS_ACCESS_KEY = ephemeral.random_password.access_key.result
    RUSTFS_SECRET_KEY = ephemeral.random_password.secret_key.result
  }

  data_wo_revision = 1
}

resource "helm_release" "this" {
  name             = "${var.name}-rustfs"
  namespace        = var.namespace
  repository       = "https://charts.rustfs.com"
  chart            = "rustfs"
  version          = "1.0.2"
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
        existingSecret = kubernetes_secret_v1.credentials.metadata[0].name
      }

      config = {
        rustfs = {
          log_level = "warn"
        }
      }
    })
  ]

  depends_on = [kubernetes_secret_v1.credentials]
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
                name = kubernetes_secret_v1.credentials.metadata[0].name
                key  = "RUSTFS_ACCESS_KEY"
              }
            }
          }

          env {
            name = "RUSTFS_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.credentials.metadata[0].name
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
