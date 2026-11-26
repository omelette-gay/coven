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

locals {
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  # Created by the CNPG cluster chart (release `db`), with the app user's credentials and connection details
  db_secret_name = "db-cluster-app"

  # Key of the OpenID provider in Vikunja's config. It's part of the redirect URI, so changing it breaks SSO until the
  # Keycloak client is updated too
  oidc_provider = "keycloak"

  trusted_ca_dir = "/etc/vikunja-ca"

  files_bucket = "vikunja"

  # Created by cert-manager for the Ingress, and also used by the router that blocks the metrics path
  tls_secret_name = "vikunja-tls"
}

# Names that are global rather than per namespace (Vault paths and roles, the Keycloak client ID and the default backup
# path) are built from the namespace, so a second install in another namespace doesn't clash with the first
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# Vikunja's service.secret, kept in Vault and synced by External Secrets Operator, so it isn't in Terraform state. It
# signs login sessions (JWTs), so increasing `revision` to rotate it logs everyone out.
module "service_secret" {
  source = "../generated-secret"

  keys                     = { secret = 64 }
  vault_secret_name        = "${local.namespace}/service-secret"
  k8s_secret_name          = "vikunja-service-secret"
  k8s_namespace            = local.namespace
  k8s_service_account_name = "vikunja-service-secret"
  vault_role_name          = "${local.namespace}-service-secret"
}

# Vikunja can't require a role or group claim, so anyone in the realm can log in and gets their own empty account.
# See docs/sso.md.
module "keycloak_client" {
  source = "../keycloak-client"

  keycloak_url        = var.keycloak_url
  secret_revision     = var.keycloak_secret_revision
  keycloak_realm      = var.keycloak_realm
  client_id           = local.namespace
  client_name         = "Vikunja"
  valid_redirect_uris = ["https://${var.host}/auth/openid/${local.oidc_provider}"]
  k8s_namespace       = local.namespace
  k8s_secret_name     = "vikunja-oidc"
}

# The GCP service account key the Barman Cloud plugin uses to write backups and WAL to GCS, as for Keycloak
module "backup_credentials" {
  source = "../vault-k8s-secret"

  vault_secret_name        = "backups/service-account-key"
  k8s_secret_name          = "vikunja-gcp-backup-creds"
  k8s_namespace            = local.namespace
  k8s_service_account_name = "vikunja-gcp-backup-creds"
  vault_role_name          = "${local.namespace}-gcp-backup-creds"
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
        # Pinned to a minimal image until there's a ClusterImageCatalog to follow (#128). Without this, the chart
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
          path   = coalesce(var.backup_path, "/cnpg/${local.namespace}/")
        }
        secret = {
          create = false
          name   = module.backup_credentials.k8s_secret_name
        }
        # Staggered from Keycloak (08:30 and 20:30)
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

# Task attachments, avatars and backgrounds, in S3 rather than on a volume mounted into Vikunja, so the app itself keeps
# no state on disk
module "object_store" {
  source = "../object-store"

  name                        = "vikunja"
  namespace                   = local.namespace
  buckets                     = [local.files_bucket]
  storage_size                = var.attachments_storage_size
  longhorn_recurring_job_name = var.longhorn_recurring_job_name
}

# Hides Vikunja's metrics from the web. Prometheus scrapes them inside the cluster.
module "block_metrics_path" {
  source = "../traefik-block-path"

  namespace       = local.namespace
  host            = var.host
  path_regexp     = "^/api/v1/metrics"
  tls_secret_name = local.tls_secret_name
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

        hostAliases = var.host_aliases

        persistence = merge(
          {
            # Files are in RustFS, and the database is in Postgres, not SQLite
            data = {
              enabled = false
            }
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
              "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd"
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
              secretName = local.tls_secret_name
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
                  publicurl          = "https://${var.host}/"
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
                files = {
                  type = "s3"
                  s3 = {
                    endpoint = module.object_store.endpoint
                    bucket   = local.files_bucket
                    # RustFS ignores the region, but the S3 client needs one to sign requests
                    region       = "us-east-1"
                    usepathstyle = true
                  }
                }
                mailer = {
                  enabled   = true
                  host      = var.smtp_host
                  port      = var.smtp_port
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
            VIKUNJA_DATABASE_TYPE      = "postgres"
            VIKUNJA_DATABASE_HOST      = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "host" } } }
            VIKUNJA_DATABASE_USER      = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "username" } } }
            VIKUNJA_DATABASE_PASSWORD  = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "password" } } }
            VIKUNJA_DATABASE_DATABASE  = { valueFrom = { secretKeyRef = { name = local.db_secret_name, key = "dbname" } } }
            VIKUNJA_SERVICE_SECRET     = { valueFrom = { secretKeyRef = { name = module.service_secret.k8s_secret_name, key = "secret" } } }
            VIKUNJA_FILES_S3_ACCESSKEY = { valueFrom = { secretKeyRef = { name = module.object_store.credentials_secret_name, key = "RUSTFS_ACCESS_KEY" } } }
            VIKUNJA_FILES_S3_SECRETKEY = { valueFrom = { secretKeyRef = { name = module.object_store.credentials_secret_name, key = "RUSTFS_SECRET_KEY" } } }

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

  depends_on = [helm_release.db, module.object_store, module.block_metrics_path]
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
