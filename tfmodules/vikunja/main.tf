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
  }
}

locals {
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  # Created by the CNPG cluster chart (release `db`), with the app user's credentials and connection details
  db_secret_name = "db-cluster-app"

  # Key of the OpenID provider in Vikunja's config. It's part of the redirect URI, so changing it breaks SSO until the
  # Keycloak client is updated too
  oidc_provider = "keycloak"

  trusted_ca_dir = "/etc/vikunja-ca"
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "vikunja"
  }
}

# Vikunja's service.secret, kept in Vault and synced by External Secrets Operator, so it isn't in Terraform state. It
# signs login sessions (JWTs), so increasing `revision` to rotate it logs everyone out.
module "service_secret" {
  source = "../generated-secret"

  keys                     = { secret = 64 }
  vault_secret_name        = "vikunja/service-secret"
  k8s_secret_name          = "vikunja-service-secret"
  k8s_namespace            = local.namespace
  k8s_service_account_name = "vikunja-service-secret"
  vault_role_name          = "vikunja-service-secret"
}

# Vikunja can't require a role or group claim, so anyone in the realm can log in and gets their own empty account.
# See docs/sso.md.
module "keycloak_client" {
  source = "../keycloak-client"

  keycloak_url        = var.keycloak_url
  secret_revision     = var.keycloak_secret_revision
  realm_id            = var.keycloak_realm
  client_id           = "vikunja"
  client_name         = "Vikunja"
  valid_redirect_uris = ["https://${var.domain}/auth/openid/${local.oidc_provider}"]
  k8s_namespace       = local.namespace
  k8s_secret_name     = "vikunja-oidc"
}

# The GCP service account key the Barman Cloud plugin uses to write backups and WAL to GCS, as for Keycloak and Planka
module "backup_credentials" {
  source = "../vault-k8s-secret"

  vault_secret_name        = "backups/service-account-key"
  k8s_secret_name          = "vikunja-gcp-backup-creds"
  k8s_namespace            = local.namespace
  k8s_service_account_name = "vikunja-gcp-backup-creds"
  vault_role_name          = "vikunja-gcp-backup-creds"
}

resource "helm_release" "db" {
  name       = "db"
  namespace  = local.namespace
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.9.0"
  atomic     = true
  wait       = true

  values = [
    yamlencode({
      cluster = {
        instances = var.postgresql_instances
        # Pinned to a minimal image until there's a ClusterImageCatalog to follow (#875). Without this, the chart
        # picks the deprecated rolling `16` tag
        imageName = "ghcr.io/cloudnative-pg/postgresql:18.7-202611122305-minimal-trixie"
        initdb = {
          database = "vikunja"
        }
        storage = {
          size = var.postgresql_storage_size
        }
        monitoring = {
          enabled = true
        }
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
          path   = var.backup_path
        }
        secret = {
          create = false
          name   = module.backup_credentials.k8s_secret_name
        }
        # Staggered from Planka (08:00 and 20:00) and Keycloak (08:30 and 20:30)
        scheduledBackups = [{
          name                 = "daily-backup"
          schedule             = "0 0 9,21 * * *"
          backupOwnerReference = "self"
          method               = "plugin"
          pluginConfiguration = {
            name = "barman-cloud.cloudnative-pg.io"
          }
        }]
      }
    })
  ]
}

# Task attachments and avatars. Made here rather than by the chart, so it can be labelled for Longhorn's off-site backup
resource "kubernetes_persistent_volume_claim_v1" "files" {
  metadata {
    name      = "vikunja-files"
    namespace = local.namespace
    labels = var.longhorn_recurring_job_name != null ? {
      "recurring-job.longhorn.io/source"                             = "enabled"
      "recurring-job.longhorn.io/${var.longhorn_recurring_job_name}" = "enabled"
    } : {}
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.attachments_storage_size
      }
    }
  }

  wait_until_bound = false
}

resource "kubernetes_manifest" "block_metrics_path" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "block-metrics-path"
      namespace = local.namespace
    }
    spec = {
      plugin = {
        "plugin-blockpath" = {
          Regex = ["^/api/v1/metrics(.*)"]
        }
      }
    }
  }
}

resource "helm_release" "this" {
  name       = "vikunja"
  namespace  = local.namespace
  repository = "oci://ghcr.io/go-vikunja/helm-chart"
  chart      = "vikunja"
  version    = "2.6.0"
  atomic     = true
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      vikunja = {
        # Restart when the Keycloak client secret is rotated, as Vikunja only reads it when it starts
        podAnnotations = {
          "omelette.gay/keycloak-secret-revision" = tostring(var.keycloak_secret_revision)
        }

        hostAliases = [for ip, hostnames in var.host_aliases : { ip = ip, hostnames = hostnames }]

        persistence = merge(
          {
            data = {
              enabled       = true
              existingClaim = kubernetes_persistent_volume_claim_v1.files.metadata[0].name
            }
            # The database is in Postgres, not SQLite
            database = {
              enabled = false
            }
          },
          var.trusted_ca_secret_name == null ? {} : {
            trusted-ca = {
              enabled   = true
              type      = "secret"
              name      = var.trusted_ca_secret_name
              mountPath = local.trusted_ca_dir
              readOnly  = true
              items     = [{ key = "ca.crt", path = "ca.crt" }]
            }
          }
        )

        ingress = {
          main = {
            enabled = true
            annotations = {
              "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
              "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd,${local.namespace}-block-metrics-path@kubernetescrd"
            }
            hosts = [{
              host = var.domain
              paths = [{
                path     = "/"
                pathType = "Prefix"
              }]
            }]
            tls = [{
              hosts      = [var.domain]
              secretName = "vikunja-tls"
            }]
          }
        }

        serviceMonitor = {
          main = {
            enabled = true
            endpoints = [{
              port          = "http"
              scheme        = "http"
              path          = "/api/v1/metrics"
              interval      = "1m"
              scrapeTimeout = "10s"
            }]
          }
        }

        # Secrets and the OpenID client ID and secret come from the environment below. Vikunja merges environment
        # variables into this config, so the provider's other keys have to be here for those to land in it.
        configMaps = {
          config = {
            enabled = true
            data = {
              "config.yml" = yamlencode({
                service = {
                  publicurl          = "https://${var.domain}/"
                  enableregistration = false
                  timezone           = "Europe/London"
                }
                auth = {
                  local = {
                    enabled = false
                  }
                  openid = {
                    enabled = true
                    providers = {
                      (local.oidc_provider) = {
                        name                = "Keycloak"
                        authurl             = "${var.keycloak_url}/realms/${var.keycloak_realm}"
                        requireavailability = true
                      }
                    }
                  }
                }
                mailer = {
                  enabled   = true
                  host      = "mail.mail.svc.cluster.local"
                  port      = 587
                  fromemail = var.sender_email
                }
                metrics = {
                  enabled = true
                }
              })
            }
          }
        }

        env = merge(
          {
            VIKUNJA_DATABASE_TYPE     = "postgres"
            VIKUNJA_DATABASE_HOST     = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "host" } } }
            VIKUNJA_DATABASE_USER     = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "username" } } }
            VIKUNJA_DATABASE_PASSWORD = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "password" } } }
            VIKUNJA_DATABASE_DATABASE = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "dbname" } } }
            VIKUNJA_SERVICE_SECRET    = { valueFrom = { secretKeyRef = { name = module.service_secret.k8s_secret_name, key = "secret" } } }

            "VIKUNJA_AUTH_OPENID_PROVIDERS_${upper(local.oidc_provider)}_CLIENTID"     = { valueFrom = { secretKeyRef = { name = module.keycloak_client.k8s_secret_name, key = "client_id" } } }
            "VIKUNJA_AUTH_OPENID_PROVIDERS_${upper(local.oidc_provider)}_CLIENTSECRET" = { valueFrom = { secretKeyRef = { name = module.keycloak_client.k8s_secret_name, key = "client_secret" } } }
          },
          # Go reads CA certificates from these directories as well as the image's bundle
          var.trusted_ca_secret_name == null ? {} : {
            SSL_CERT_DIR = local.trusted_ca_dir
          }
        )
      }
    })
  ]

  depends_on = [helm_release.db, kubernetes_manifest.block_metrics_path]
}

resource "kubernetes_manifest" "probe" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "vikunja-https"
      namespace = local.namespace
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober = {
        url  = "blackbox-exporter-prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115"
        path = "/probe"
      }
      targets = {
        staticConfig = {
          static = ["https://${var.domain}/"]
        }
      }
    }
  }

  depends_on = [helm_release.this]
}
