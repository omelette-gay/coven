# kube-prometheus-stack and Grafana are installed by bootstrap. This is what needs Vault or Keycloak, and the logging
# stack, which nothing in bootstrap depends on.

# Grafana's SSO client. Grafana's Helm values in bootstrap already point at this client and its Secret.
module "grafana_sso" {
  source = "../keycloak-client"

  keycloak_realm      = keycloak_realm.omelette_gay.id
  client_id           = "grafana"
  client_name         = "grafana"
  valid_redirect_uris = ["https://${var.grafana_host}/login/generic_oauth"]
  client_roles        = ["grafana-admin"]
  keycloak_url        = var.keycloak_url
  k8s_namespace       = var.namespaces.monitoring
  k8s_secret_name     = var.grafana_oauth_secret
  secret_revision     = var.grafana_keycloak_secret_revision
}

# Not exhaustive, as the apps stack's sso-groups.tf manages the full list of the group's roles (see docs/sso.md)
resource "keycloak_group_roles" "admins_grafana" {
  realm_id   = keycloak_realm.omelette_gay.id
  group_id   = keycloak_group.admins.id
  role_ids   = [module.grafana_sso.role_ids["grafana-admin"]]
  exhaustive = false
}

# The grant used to be made by the keycloak-client module
moved {
  from = module.grafana_sso.keycloak_group_roles.this["admins"]
  to   = keycloak_group_roles.admins_grafana
}

# Checks over HTTPS that the services bootstrap installs are up (the HttpProbeFailed alert)
locals {
  probes = {
    keycloak = { namespace = var.namespaces.keycloak, url = "${var.keycloak_url}/realms/master/" }
    vault    = { namespace = var.namespaces.vault, url = "https://${var.vault_host}/ui/vault/auth" }
    grafana  = { namespace = var.namespaces.monitoring, url = "https://${var.grafana_host}/login" }
  }
}

# Grafana reads its SSO Secret only when it starts, so this annotation on its pods restarts it when the secret rotates.
# Grafana is installed by bootstrap's kube-prometheus-stack (release kube-prometheus); Helm leaves the annotation alone.
resource "kubernetes_annotations" "grafana_sso_revision" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "kube-prometheus-grafana"
    namespace = var.namespaces.monitoring
  }
  template_annotations = {
    "omelette.gay/sso-secret-revision" = tostring(var.grafana_keycloak_secret_revision)
  }

  depends_on = [module.grafana_sso]
}

resource "kubernetes_manifest" "probe" {
  for_each = local.probes

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "${each.key}-https"
      namespace = each.value.namespace
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober   = local.blackbox_prober
      targets = {
        staticConfig = {
          static = [each.value.url]
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

  vault_secret_name             = "gitops/grafana-discord-notifier"
  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
  k8s_secret_name               = "grafana-discord-notifier"
  k8s_secret_labels             = { grafana_alert = "1" }
  k8s_namespace                 = var.namespaces.monitoring
  k8s_service_account_name      = "grafana-discord-notifier"
  vault_role_name               = "grafana-discord-notifier"
  template_data = {
    "discord-notifier.yaml" = <<-EOT
      apiVersion: 1
      contactPoints:
        - name: Discord
          receivers:
            - uid: discord
              type: discord
              settings:
                avatar_url: https://${var.grafana_host}/public/img/grafana_icon.svg
                url: {{ .webhook_url }}
                use_discord_username: true
              disableResolveMessage: false
    EOT
  }
}

module "alertmanager_discord_webhook" {
  source = "../vault-k8s-secret"
  count  = var.discord_alerts ? 1 : 0

  vault_secret_name             = "gitops/grafana-discord-notifier"
  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
  k8s_secret_name               = "discord-alerting-webhook"
  k8s_namespace                 = var.namespaces.monitoring
  k8s_service_account_name      = "discord-alerting-webhook"
  vault_role_name               = "discord-alerting-webhook"
}

resource "kubernetes_manifest" "alertmanager_discord" {
  count = var.discord_alerts ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"
    metadata = {
      name      = "alertmanager-discord-notifier"
      namespace = var.namespaces.monitoring
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

module "logging" {
  source = "../logging"

  namespace           = var.namespaces.monitoring
  storage_size        = var.loki_storage_size
  chunks_cache_memory = var.loki_chunks_cache_memory

  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
}
