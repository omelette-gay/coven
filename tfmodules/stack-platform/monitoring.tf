# kube-prometheus-stack and Grafana are installed by bootstrap. This is what needs Vault or Keycloak, and the logging
# stack, which nothing in bootstrap depends on.

# Grafana's SSO client. Grafana's Helm values in bootstrap already point at this client and its Secret, and Grafana reads
# the Secret when it starts, so restart Grafana after rotating it.
module "grafana_sso" {
  source = "../keycloak-client"

  realm_id            = keycloak_realm.omelette_gay.id
  client_id           = "grafana"
  client_name         = "grafana"
  valid_redirect_uris = ["https://${local.grafana_host}/login/generic_oauth"]
  client_roles        = ["grafana-admin"]
  role_groups         = { grafana-admin = [keycloak_group.admins.name] }
  group_ids           = { (keycloak_group.admins.name) = keycloak_group.admins.id }
  keycloak_url        = var.keycloak_url
  k8s_namespace       = "monitoring"
  k8s_secret_name     = "grafana-keycloak-creds"
  secret_revision     = var.grafana_keycloak_secret_revision
}

resource "kubernetes_manifest" "grafana_probe" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "grafana-https"
      namespace = "monitoring"
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober   = local.blackbox_prober
      targets = {
        staticConfig = {
          static = ["https://${local.grafana_host}/login"]
        }
      }
    }
  }
}

# Alerts go to Discord, through a webhook whose URL is in Vault. Grafana's sidecar provisions the contact point from the
# labelled Secret, and Alertmanager reads the URL from the other.
module "grafana_discord_contact_point" {
  source = "../vault-k8s-secret"
  count  = var.discord_alerts ? 1 : 0

  vault_secret_name        = "gitops/grafana-discord-notifier"
  k8s_secret_name          = "grafana-discord-notifier"
  k8s_secret_labels        = { grafana_alert = "1" }
  k8s_namespace            = "monitoring"
  k8s_service_account_name = "grafana-discord-notifier"
  vault_role_name          = "grafana-discord-notifier"
  template_data = {
    "discord-notifier.yaml" = <<-EOT
      apiVersion: 1
      contactPoints:
        - name: Discord
          receivers:
            - uid: discord
              type: discord
              settings:
                avatar_url: https://${local.grafana_host}/public/img/grafana_icon.svg
                url: {{ .webhook_url }}
                use_discord_username: true
              disableResolveMessage: false
    EOT
  }
}

module "alertmanager_discord_webhook" {
  source = "../vault-k8s-secret"
  count  = var.discord_alerts ? 1 : 0

  vault_secret_name        = "gitops/grafana-discord-notifier"
  k8s_secret_name          = "discord-alerting-webhook"
  k8s_namespace            = "monitoring"
  k8s_service_account_name = "discord-alerting-webhook"
  vault_role_name          = "discord-alerting-webhook"
}

resource "kubernetes_manifest" "alertmanager_discord" {
  count = var.discord_alerts ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"
    metadata = {
      name      = "alertmanager-discord-notifier"
      namespace = "monitoring"
    }
    spec = {
      route = {
        groupBy        = ["namespace", "alertname"]
        receiver       = "discord-receiver"
        repeatInterval = "7d"
      }
      receivers = [{
        name = "discord-receiver"
        discordConfigs = [{
          apiURL = {
            name = module.alertmanager_discord_webhook[0].k8s_secret_name
            key  = "webhook_url"
          }
        }]
      }]
    }
  }
}

# Logs: Alloy on each node sends pods' logs, the systemd journal and Kubernetes events to Loki, which keeps them in RustFS
module "loki_object_store" {
  source = "../object-store"

  name         = "loki"
  namespace    = "monitoring"
  storage_size = var.loki_storage_size
  buckets      = ["loki-chunks", "loki-ruler", "loki-admin"]
  otlp_metrics = true
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "monitoring"
  repository = "https://grafana-community.github.io/helm-charts/"
  chart      = "loki"
  version    = "21.2.3"
  atomic     = true
  wait       = true
  timeout    = 600

  values = [templatefile("${path.module}/values/loki.yaml.tftpl", {
    object_store_secret   = module.loki_object_store.credentials_secret_name
    object_store_endpoint = module.loki_object_store.endpoint
    chunks_cache_memory   = var.loki_chunks_cache_memory
  })]
}

resource "kubernetes_config_map_v1" "loki_data_source" {
  metadata {
    name      = "loki-data-source"
    namespace = "monitoring"
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-stack-datasource.yaml" = chomp(<<-EOT
      apiVersion: 1
      datasources:
        - name: Loki
          type: loki
          access: proxy
          url: http://loki-gateway
          version: 1
    EOT
    )
  }
}

resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.16.0"
  atomic     = true
  wait       = true

  values = [file("${path.module}/values/alloy.yaml")]

  depends_on = [helm_release.loki]
}
