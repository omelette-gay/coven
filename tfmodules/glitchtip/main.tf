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

resource "helm_release" "this" {
  name          = "glitchtip"
  namespace     = kubernetes_namespace_v1.this.metadata[0].name
  repository    = "https://gitlab.com/api/v4/projects/16325141/packages/helm/stable"
  chart         = "glitchtip"
  version       = "9.2.0"
  timeout       = 900
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      glitchtip = {
        existingSecret = module.secret_key.k8s_secret_name
        domain         = "https://${var.host}"
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

      postgresql = {
        enabled = true
        cluster = {
          instances = var.postgresql_instances
          storage = {
            size = var.postgresql_storage_size
          }
          monitoring = {
            enabled = true
          }
        }
      }
    })
  ]

  depends_on = [module.object_store, kubernetes_manifest.block_metrics_path]
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
                name = "glitchtip-pg-app"
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
