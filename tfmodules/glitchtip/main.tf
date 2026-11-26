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
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "glitchtip"
  }
}

# GlitchTip's Django SECRET_KEY, kept in Vault and synced by External Secrets Operator, so it isn't in Terraform state.
# It only signs sessions, cookies and password-reset tokens (SSO is the only way in, so there's no MFA to break), so
# increasing `revision` to rotate it just logs everyone out. The Secret is named differently to the one Terraform used to
# make, as ESO won't take over an existing Secret.
module "secret_key" {
  source = "../generated-secret"

  keys                     = { SECRET_KEY = 64 }
  vault_secret_name        = "glitchtip/secret-key"
  k8s_secret_name          = "glitchtip-secret-key"
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "glitchtip-secret-key"
  vault_role_name          = "glitchtip-secret-key"

  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
}

module "keycloak_client" {
  source = "../keycloak-client"

  keycloak_url        = var.keycloak_url
  secret_revision     = var.keycloak_secret_revision
  keycloak_realm      = var.keycloak_realm
  client_id           = "glitchtip"
  client_name         = "GlitchTip"
  valid_redirect_uris = ["https://${var.host}/accounts/oidc/keycloak/login/callback/"]
  k8s_namespace       = kubernetes_namespace_v1.this.metadata[0].name
  k8s_secret_name     = "glitchtip-oidc"
}

module "object_store" {
  source = "../object-store"

  name      = "glitchtip"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  buckets   = ["glitchtip"]

  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
}

resource "kubernetes_manifest" "block_metrics_path" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "block-metrics-path"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      plugin = {
        "plugin-blockpath" = {
          Regex = ["^/metrics(.*)"]
        }
      }
    }
  }
}

locals {
  # Created by the CNPG cluster chart (release `db`), with the app user's credentials and connection details
  db_secret_name = "db-cluster-app"

  # GlitchTip's PostgreSQL major version. Changing it upgrades the database in place, with downtime: read "Major
  # upgrades" in docs/backups-and-recovery.md first
  postgresql_major = "18"
}

# The GCP service account key the Barman Cloud plugin uses to write backups and WAL to GCS, as for Keycloak
module "backup_credentials" {
  source = "../vault-k8s-secret"
  count  = var.backup_bucket != null ? 1 : 0

  vault_secret_name             = "backups/service-account-key"
  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
  k8s_secret_name               = "glitchtip-gcp-backup-creds"
  k8s_namespace                 = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name      = "glitchtip-gcp-backup-creds"
  vault_role_name               = "glitchtip-gcp-backup-creds"
}

# GlitchTip's database. It's made with the CNPG cluster chart rather than the GlitchTip chart's own `postgresql`, which
# can't set an image (so it couldn't use the shared catalog, see ADR 007) and ignores monitoring.
#
# It was first created by importing the database from the GlitchTip chart's cluster, `glitchtip-pg` (#128). The import
# only runs when the cluster is created, so the settings below do nothing afterwards, and are removed once the old
# cluster is deleted.
resource "helm_release" "db" {
  name       = "db"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.9.0"
  atomic     = true
  wait       = true
  # importing the old database happens before the cluster is ready
  timeout = 900

  # Two values documents, which Helm merges deeply, so the backup settings can add to `cluster`
  values = concat(
    [yamlencode({
      mode = "recovery"

      # GlitchTip's major version, with its image from the shared catalog (see ADR 007)
      version = { postgresql = local.postgresql_major }
      cluster = {
        instances = var.postgresql_instances
        imageCatalogRef = {
          kind = "ClusterImageCatalog"
          name = var.postgresql_image_catalog
        }
        initdb = {
          database = "glitchtip"
          owner    = "glitchtip"
        }
        storage = {
          size = var.postgresql_storage_size
        }
        monitoring = {
          enabled = true
        }
      }

      recovery = {
        method = "import"
        import = {
          type      = "microservice"
          databases = ["glitchtip"]
          source = {
            host     = "glitchtip-pg-rw"
            port     = 5432
            username = "glitchtip"
            database = "glitchtip"
            sslMode  = "verify-full"
            passwordSecret = {
              name = "glitchtip-pg-app"
              key  = "password"
            }
            sslRootCertSecret = {
              name = "glitchtip-pg-ca"
              key  = "ca.crt"
            }
          }
        }
      }
    })],
    # with no backup bucket (the testlab), the database isn't backed up
    var.backup_bucket == null ? [] : [yamlencode({
      cluster = {
        plugins = [{
          name = "barman-cloud.cloudnative-pg.io"
          parameters = {
            # An upgrade to a new major starts a new database system, whose WAL would overwrite the old one's in the same
            # archive, so each major archives under its own name (see docs/backups-and-recovery.md)
            serverName = "db-cluster-pg${local.postgresql_major}"
          }
        }]
      }
      backups = {
        enabled = true
        method  = "plugin"
        pluginConfiguration = {
          name = "barman-cloud.cloudnative-pg.io"
        }
        provider = "google"
        google = {
          bucket = var.backup_bucket
          path   = "/cnpg/glitchtip/"
        }
        secret = {
          name   = module.backup_credentials[0].k8s_secret_name
          create = false
        }
        # Staggered from Keycloak (08:30 and 20:30) and Vikunja (09:00 and 21:00)
        scheduledBackups = [{
          name                 = "daily-backup"
          schedule             = "0 30 9,21 * * *"
          backupOwnerReference = "self"
          method               = "plugin"
          pluginConfiguration = {
            name = "barman-cloud.cloudnative-pg.io"
          }
        }]
      }
    })],
  )
}

# Backs up RustFS's volume (uploaded files such as source maps) with a Longhorn recurring job. The RustFS chart made the
# volume, so it's labelled here rather than by the object-store module, which would switch to a new, empty volume.
# Longhorn copies a PVC's recurring job labels to its volume when it has the `source` label
resource "kubernetes_labels" "object_store_backup" {
  count = var.longhorn_recurring_job_name != null ? 1 : 0

  api_version = "v1"
  kind        = "PersistentVolumeClaim"
  metadata {
    name      = "glitchtip-rustfs-data"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  labels = {
    "recurring-job.longhorn.io/${var.longhorn_recurring_job_name}" = "enabled"
    "recurring-job.longhorn.io/source"                             = "enabled"
  }

  depends_on = [module.object_store]
}

resource "helm_release" "this" {
  name          = "glitchtip"
  namespace     = kubernetes_namespace_v1.this.metadata[0].name
  repository    = "https://gitlab.com/api/v4/projects/16325141/packages/helm/stable"
  chart         = "glitchtip"
  version       = "9.2.0"
  atomic        = true
  timeout       = 900
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      glitchtip = {
        existingSecret = module.secret_key.k8s_secret_name
        domain         = "https://${var.host}"
        database = {
          existingSecret    = local.db_secret_name
          existingSecretKey = "uri"
        }
      }

      extraEnvVars = [
        {
          name  = "ENABLE_USER_REGISTRATION"
          value = "false"
        },
        {
          name  = "ENABLE_SOCIAL_APPS_USER_REGISTRATION"
          value = "true"
        },
        {
          name  = "GLITCHTIP_ENABLE_LOGS"
          value = "false"
        },
        {
          name  = "GLITCHTIP_ENABLE_UPTIME"
          value = "false"
        },
        {
          name  = "ENABLE_OBSERVABILITY_API"
          value = "true"
        },
        {
          name  = "GLITCHTIP_ENABLE_DUCKDB"
          value = "true"
        },
        {
          name  = "DEFAULT_FILE_STORAGE"
          value = "storages.backends.s3boto3.S3Boto3Storage"
        },
        {
          name  = "AWS_STORAGE_BUCKET_NAME"
          value = "glitchtip"
        },
        {
          name  = "AWS_S3_ENDPOINT_URL"
          value = module.object_store.endpoint
        },
        {
          name  = "AWS_S3_ADDRESSING_STYLE"
          value = "path"
        },
        {
          name = "AWS_ACCESS_KEY_ID"
          valueFrom = {
            secretKeyRef = {
              name = module.object_store.credentials_secret_name
              key  = "RUSTFS_ACCESS_KEY"
            }
          }
        },
        {
          name = "AWS_SECRET_ACCESS_KEY"
          valueFrom = {
            secretKeyRef = {
              name = module.object_store.credentials_secret_name
              key  = "RUSTFS_SECRET_KEY"
            }
          }
        },
        {
          name  = "EMAIL_URL",
          value = "smtp://${var.smtp_host}:${var.smtp_port}"
        },
        {
          name  = "DEFAULT_FROM_EMAIL",
          value = var.sender_email
        }
      ]

      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
          "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd,${kubernetes_namespace_v1.this.metadata[0].name}-block-metrics-path@kubernetescrd"
        }
        hosts = [{
          host = var.host
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }]
        tls = [{
          hosts      = [var.host]
          secretName = "glitchtip-tls"
        }]
      }

      monitoring = {
        enabled = true
      }

      valkey = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      # The database is the `db` release above. Turning this off removes the chart's old cluster, `glitchtip-pg`, from
      # the release; it's annotated so Helm leaves it running, until it's deleted by hand after the migration (#128)
      postgresql = {
        enabled = false
      }
    })
  ]

  depends_on = [module.object_store, kubernetes_manifest.block_metrics_path, helm_release.db]
}

# The Job below copies the Keycloak client secret into GlitchTip's database, and a Job only runs once, so it has to be
# replaced to run again after the secret is rotated. This changes when keycloak_secret_revision does, which is also
# what rotates the secret. It's created with the revision, so adding it doesn't re-run the Job.
resource "terraform_data" "oidc_secret_revision" {
  input = var.keycloak_secret_revision
}

resource "kubernetes_job_v1" "configure_oidc" {
  metadata {
    name      = "glitchtip-configure-oidc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    backoff_limit = 6

    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name = "configure-oidc"
          # The same GlitchTip version as the chart deploys (its appVersion), so the Job never runs a different version to the
          # database it writes to. It's known after apply when the chart is upgraded, which replaces the Job to run it again
          image   = "glitchtip/glitchtip:${helm_release.this.metadata.app_version}"
          command = ["python", "manage.py", "shell", "-c"]
          args = [<<-PYTHON
            import os
            from allauth.socialaccount.models import SocialApp

            app, _ = SocialApp.objects.update_or_create(
                provider="openid_connect",
                provider_id="keycloak",
                defaults={
                    "name": "Keycloak",
                    "client_id": os.environ["KEYCLOAK_CLIENT_ID"],
                    "secret": os.environ["KEYCLOAK_CLIENT_SECRET"],
                    "settings": {
                        "server_url": os.environ["KEYCLOAK_SERVER_URL"]
                        + "/realms/"
                        + os.environ["KEYCLOAK_REALM"]
                        + "/.well-known/openid-configuration"
                    },
                },
            )
          PYTHON
          ]

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = local.db_secret_name
                key  = "uri"
              }
            }
          }

          env {
            name = "KEYCLOAK_CLIENT_ID"
            value_from {
              secret_key_ref {
                name = module.keycloak_client.k8s_secret_name
                key  = "client_id"
              }
            }
          }

          env {
            name = "KEYCLOAK_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = module.keycloak_client.k8s_secret_name
                key  = "client_secret"
              }
            }
          }

          env {
            name  = "KEYCLOAK_SERVER_URL"
            value = var.keycloak_url
          }

          env {
            name  = "KEYCLOAK_REALM"
            value = var.keycloak_realm
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.oidc_secret_revision]
  }

  depends_on = [helm_release.this, module.keycloak_client]
}

resource "kubernetes_manifest" "probe" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "glitchtip-https"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober   = var.blackbox_prober
      targets = {
        staticConfig = {
          static = ["https://${var.host}/"]
        }
      }
    }
  }

  depends_on = [helm_release.this]
}
