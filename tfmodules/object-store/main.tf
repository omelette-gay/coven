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

  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
}

# Only made here when the volume needs backing up: the chart can only label its own volume through commonLabels, which
# would also change the pods' selector labels
resource "kubernetes_persistent_volume_claim_v1" "data" {
  count = var.longhorn_recurring_job_name != null ? 1 : 0

  metadata {
    name      = "${var.name}-object-store-data"
    namespace = var.namespace
    labels = {
      "recurring-job.longhorn.io/source"                             = "enabled"
      "recurring-job.longhorn.io/${var.longhorn_recurring_job_name}" = "enabled"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "longhorn"
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  wait_until_bound = false
}

resource "helm_release" "this" {
  name             = "${var.name}-rustfs"
  namespace        = var.namespace
  repository       = "https://charts.rustfs.com"
  chart            = "rustfs"
  version          = "1.0.6"
  atomic           = true
  create_namespace = false
  wait             = true

  # compact drops the metrics values when they're off, so other stores' values don't change
  values = compact([
    yamlencode({
      mode = {
        standalone = merge(
          { enabled = true },
          var.longhorn_recurring_job_name != null ? {
            existingClaim = { dataClaim = kubernetes_persistent_volume_claim_v1.data[0].metadata[0].name }
          } : {}
        )
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

      # Without this, the kubelet changes the owner of every file on the volume each time RustFS starts, which took
      # about an hour for Loki's 50Gi. This only does it when the volume's top folder is wrong.
      podSecurityContext = {
        fsGroupChangePolicy = "OnRootMismatch"
      }

      secret = {
        existingSecret = module.credentials.k8s_secret_name
      }

      config = {
        rustfs = merge(
          { log_level = "warn" },
          var.otlp_metrics ? {
            obs_endpoint = {
              enabled       = true
              base_endpoint = "http://kube-prometheus-kube-prome-prometheus.monitoring.svc.cluster.local:9090/api/v1/otlp"
              use_stdout    = true
              metrics       = { enabled = true }
            }
          } : {}
        )
      }
    }),
    # labels for the metrics RustFS sends Prometheus
    var.otlp_metrics ? yamlencode({
      extraEnv = [
        { name = "OTEL_SERVICE_NAME", value = "${var.name}-rustfs" },
        { name = "K8S_POD_NAME", valueFrom = { fieldRef = { fieldPath = "metadata.name" } } },
        {
          name  = "OTEL_RESOURCE_ATTRIBUTES"
          value = "service.namespace=${var.namespace},service.instance.id=$(K8S_POD_NAME),k8s.namespace.name=${var.namespace},k8s.pod.name=$(K8S_POD_NAME)"
        },
      ]
    }) : "",
  ])
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
          image   = "rustfs/rc:${local.rc_image_tag}"
          command = ["/bin/sh", "-c"]
          args = [<<-SHELL
            set -eu
            rc alias set object-store ${local.endpoint} "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY"
            rc bucket create object-store/${each.key} --ignore-existing
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
