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
  # e.g. auth.coven.omelette.gay and /auth
  host      = regex("^https://([^/]+)", var.url)[0]
  base_path = trimprefix(var.url, "https://${local.host}")
}

resource "kubernetes_namespace_v1" "keycloak" {
  metadata {
    name = var.namespace
    # set by Ansible on coven, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

locals {
  # Keycloak's PostgreSQL major version. Changing it upgrades the database in place, with downtime: read "Major upgrades"
  # in docs/backups-and-recovery.md first
  postgresql_major = "18"
}

# Keycloak's database. Backups go to GCS with the service account key platform syncs from Vault, so on a fresh cluster
# they fail until platform has been applied. Without a backup_bucket there are no backups.
resource "helm_release" "keycloak_db" {
  name       = "db"
  namespace  = kubernetes_namespace_v1.keycloak.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.9.0"
  atomic     = true
  wait       = true

  # Two values documents, which Helm merges deeply, so the backup settings can add to `cluster`
  values = concat(
    [yamlencode({
      # Keycloak's major version, with its image from the shared catalog (see ADR 009). Changing the major upgrades the
      # database in place
      version = { postgresql = local.postgresql_major }
      cluster = {
        instances = 2
        imageCatalogRef = {
          kind = "ClusterImageCatalog"
          name = var.postgresql_image_catalog
        }
        initdb = {
          database = "keycloak"
        }
        # The database was created on the legacy `postgresql:16` image, whose initdb wrote en_US.utf8 into
        # postgresql.conf for these. The catalog's minimal images only have the C locales, so Postgres won't start
        # with those lines. Setting them here puts them in CNPG's include file, which comes later and wins
        postgresql = {
          parameters = {
            lc_messages = "C.UTF-8"
            lc_monetary = "C.UTF-8"
            lc_numeric  = "C.UTF-8"
            lc_time     = "C.UTF-8"
          }
        }
        monitoring = { enabled = true }
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
          path   = "/cnpg/keycloak/"
        }
        secret = {
          name   = var.backup_credentials_secret
          create = false
        }
        scheduledBackups = [{
          name                 = "daily-backup"
          schedule             = "0 30 8,20 * * *"
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

# The temporary admin Keycloak creates on its first start, only on a fresh cluster. Keycloak reads it through optional
# environment variables, so its Helm values are the same whether this exists or not, and deleting it doesn't restart
# Keycloak. Its password is in this stack's state while it exists.
resource "kubernetes_secret_v1" "keycloak_bootstrap_admin" {
  count = var.bootstrap_admin_password != null ? 1 : 0

  metadata {
    name      = "keycloak-bootstrap-admin"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  data = {
    username = var.bootstrap_admin_username
    password = var.bootstrap_admin_password
  }
}

# Keycloak itself. The realm, groups, clients and Terraform's own admin user are made by platform, through the keycloak
# provider, which needs Keycloak running.
resource "helm_release" "keycloak" {
  name       = "keycloak"
  namespace  = kubernetes_namespace_v1.keycloak.metadata[0].name
  repository = "https://codecentric.github.io/helm-charts"
  chart      = "keycloakx"
  version    = "7.4.0"
  atomic     = true
  wait       = true
  timeout    = 600

  values = [yamlencode({
    command = [
      "/opt/keycloak/bin/kc.sh",
      "start",
      "--http-port=8080",
      "--hostname=${var.url}",
    ]
    extraEnv = <<-EOT
      - name: JAVA_OPTS_APPEND
        value: >-
          -Djgroups.dns.query=keycloak-keycloakx-headless
      - name: KC_PROXY
        value: "edge"
      # Count logins, failed logins and other user events in Keycloak's own metrics, as keycloak_user_events_total
      - name: KC_EVENT_METRICS_USER_ENABLED
        value: "true"
      # The default pool of 100 is more than Postgres allows (100 less its superuser slots), so a burst could exhaust
      # the database as it did Vikunja's (docs/incidents/2026-11-27-vikunja-exhausted-postgres-connections-during-bulk-update.md)
      - name: KC_DB_POOL_MAX_SIZE
        value: "20"
      - name: KC_BOOTSTRAP_ADMIN_USERNAME
        valueFrom:
          secretKeyRef:
            name: keycloak-bootstrap-admin
            key: username
            optional: true
      - name: KC_BOOTSTRAP_ADMIN_PASSWORD
        valueFrom:
          secretKeyRef:
            name: keycloak-bootstrap-admin
            key: password
            optional: true
    EOT

    dbchecker = { enabled = true }

    database = {
      vendor = "postgres"
      # the cluster chart names the database cluster <release>-cluster
      hostname          = "${helm_release.keycloak_db.name}-cluster-rw"
      port              = 5432
      database          = "keycloak"
      username          = "keycloak"
      existingSecret    = "${helm_release.keycloak_db.name}-cluster-app"
      existingSecretKey = "password"
    }

    # Keycloak serves its metrics on the management port (9000), which isn't exposed through the Ingress, so they
    # don't need hiding from the web
    serviceMonitor = { enabled = true }
    prometheusRule = { enabled = true }

    # expose Keycloak to the public Internet
    proxy = {
      enabled = true
      mode    = "xforwarded"
      http    = { enabled = true }
    }
    ingress = {
      enabled = true
      rules = [{
        host  = local.host
        paths = [{ path = "${local.base_path}/", pathType = "Prefix" }]
      }]
      annotations = {
        "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
        "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd"
      }
      tls = [{
        hosts      = [local.host]
        secretName = "keycloak-tls"
      }]
    }
  })]

  depends_on = [helm_release.keycloak_db]
}
