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

  # Created by cert-manager for the Ingress, and also used by the router that blocks the metrics path
  tls_secret_name = "keycloak-tls"
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

  values = [yamlencode(merge(
    {
      cluster = {
        instances = 2
        initdb = {
          database = "keycloak"
        }
        monitoring = { enabled = true }
      }
    },
    # with no backup bucket (the testlab), the database isn't backed up
    var.backup_bucket == null ? {} : {
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
    },
  ))]
}

# Hides Keycloak's realm metrics from the web. Prometheus scrapes them inside the cluster.
module "block_metrics_path" {
  source = "../traefik-block-path"

  namespace       = kubernetes_namespace_v1.keycloak.metadata[0].name
  host            = local.host
  path_regexp     = "^${local.base_path}/realms/[^/]*/metrics"
  tls_secret_name = local.tls_secret_name
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

locals {
  # renovate: datasource=github-releases depName=aerogear/keycloak-metrics-spi
  keycloak_metrics_spi_version = "7.0.0"
  # renovate: datasource=docker depName=alpine
  init_image_tag = "3.24.4"
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

    # configure monitoring for Keycloak
    serviceMonitor = { enabled = true }
    prometheusRule = { enabled = true }

    # use the extra metrics-spi-provider plugin to expose realm metrics for Keycloak
    extraServiceMonitor = { enabled = true }
    extraInitContainers = <<-EOT
      - name: metrics-spi-provider
        image: alpine:${local.init_image_tag}
        imagePullPolicy: IfNotPresent
        command:
          - sh
        args:
          - -c
          - |
            echo "Downloading metrics-spi-provider"
            wget -O /providers/keycloak-metrics-spi.jar https://github.com/aerogear/keycloak-metrics-spi/releases/download/${local.keycloak_metrics_spi_version}/keycloak-metrics-spi-${local.keycloak_metrics_spi_version}.jar
        volumeMounts:
          - name: providers
            mountPath: /providers
    EOT
    extraVolumeMounts   = <<-EOT
      - name: providers
        mountPath: /opt/keycloak/providers
    EOT
    extraVolumes        = <<-EOT
      - name: providers
        emptyDir: {}
    EOT

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
        secretName = local.tls_secret_name
      }]
    }
  })]

  depends_on = [helm_release.keycloak_db, module.block_metrics_path]
}
