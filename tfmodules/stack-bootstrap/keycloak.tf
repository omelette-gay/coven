resource "kubernetes_namespace_v1" "keycloak" {
  metadata {
    name = "keycloak"
    # set by Ansible on coven, kept so the import doesn't change it
    labels = {
      name = "keycloak"
    }
  }
}

# Keycloak's database. Backups go to GCS with the service account key platform syncs from Vault, so on a fresh cluster
# they fail until platform has been applied.
resource "helm_release" "keycloak_db" {
  name       = "db"
  namespace  = kubernetes_namespace_v1.keycloak.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.9.0"
  atomic     = true
  wait       = true

  values = [yamlencode({
    cluster = {
      instances = 2
      initdb = {
        database = "keycloak"
      }
      monitoring = { enabled = true }
    }
    backups = {
      enabled = true
      method  = "plugin"
      pluginConfiguration = {
        name = "barman-cloud.cloudnative-pg.io"
      }
      provider = "google"
      google = {
        bucket = "coven-backups"
        path   = "/cnpg/keycloak/"
      }
      secret = {
        name   = "keycloak-gcp-backup-creds"
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
  })]

  depends_on = [helm_release.cnpg, helm_release.plugin_barman_cloud]
}

# Hides Keycloak's realm metrics from the web. Prometheus scrapes them inside the cluster.
resource "kubernetes_manifest" "keycloak_block_metrics_path" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "block-metrics-path"
      namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
    }
    spec = {
      plugin = {
        plugin-blockpath = {
          Regex = ["^/auth/realms/([^/]*)/metrics(.*)"]
        }
      }
    }
  }
}

# The temporary admin Keycloak creates on its first start, only on a fresh cluster. Keycloak reads it through optional
# environment variables, so its Helm values are the same whether this exists or not, and deleting it doesn't restart
# Keycloak. Its password is in this stack's state while it exists.
resource "kubernetes_secret_v1" "keycloak_bootstrap_admin" {
  count = var.keycloak_bootstrap_admin_password != null ? 1 : 0

  metadata {
    name      = "keycloak-bootstrap-admin"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  data = {
    username = "temp-admin"
    password = var.keycloak_bootstrap_admin_password
  }
}

locals {
  keycloak_metrics_spi_version = "7.0.0"
}

# Keycloak itself. The realm, groups, clients and Terraform's own admin user are made by platform, through the keycloak
# provider, which needs Keycloak running.
resource "helm_release" "keycloak" {
  name       = "keycloak"
  namespace  = kubernetes_namespace_v1.keycloak.metadata[0].name
  repository = "https://codecentric.github.io/helm-charts/"
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
      "--hostname=${local.keycloak_url}",
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
      vendor            = "postgres"
      hostname          = "db-cluster-rw"
      port              = 5432
      database          = "keycloak"
      username          = "keycloak"
      existingSecret    = "db-cluster-app"
      existingSecretKey = "password"
    }

    # configure monitoring for Keycloak
    serviceMonitor = { enabled = true }
    prometheusRule = { enabled = true }

    # use the extra metrics-spi-provider plugin to expose realm metrics for Keycloak
    extraServiceMonitor = { enabled = true }
    extraInitContainers = <<-EOT
      - name: metrics-spi-provider
        image: alpine:latest
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
        host  = local.keycloak_host
        paths = [{ path = "/auth/", pathType = "Prefix" }]
      }]
      annotations = {
        "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
        "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd,keycloak-block-metrics-path@kubernetescrd"
      }
      tls = [{
        hosts      = [local.keycloak_host]
        secretName = "keycloak-tls"
      }]
    }
  })]

  depends_on = [
    helm_release.keycloak_db,
    helm_release.cert_manager,
    kubernetes_manifest.redirect_https,
    kubernetes_manifest.keycloak_block_metrics_path,
  ]
}
