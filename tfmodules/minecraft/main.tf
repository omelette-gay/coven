terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "minecraft-${var.server_id}"
  }
}

resource "random_password" "rcon" {
  count   = var.backups_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "rcon" {
  count = var.backups_enabled ? 1 : 0

  metadata {
    name      = "${var.server_id}-rcon"
    namespace = resource.kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "rcon-password" = random_password.rcon[0].result
  }
}

resource "kubernetes_persistent_volume_claim_v1" "backups" {
  count = var.backups_enabled ? 1 : 0

  metadata {
    name      = "${var.server_id}-minecraft-backupdir"
    namespace = resource.kubernetes_namespace_v1.this.metadata[0].name
    labels = var.longhorn_recurring_job_name != null ? {
      "recurring-job.longhorn.io/source"                             = "enabled"
      "recurring-job.longhorn.io/${var.longhorn_recurring_job_name}" = "enabled"
    } : {}
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.backup_disk_size
      }
    }
  }
}

resource "helm_release" "minecraft" {
  name       = var.server_id
  namespace  = resource.kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://itzg.github.io/minecraft-server-charts/"
  chart      = "minecraft"
  version    = "5.2.0"
  values = [
    yamlencode({
      minecraftServer = {
        eula       = true
        difficulty = "normal"
        type       = "PAPER"
        whitelist  = join(",", var.whitelist)
        ops        = join(",", var.ops)
        motd       = var.motd

        pluginUrls = ["https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v3.1.2/minecraft-prometheus-exporter-3.1.2.jar"]

        serviceType = "LoadBalancer"
        servicePort = var.port
        extraPorts = [
          {
            name          = "metrics"
            containerPort = 9940
            service = {
              enabled  = true
              embedded = false # do not expose to the world
              port     = 9940
            }
          }
        ]

        memory = var.memory
        tty    = false

        rcon = {
          enabled        = var.backups_enabled
          existingSecret = var.backups_enabled ? kubernetes_secret_v1.rcon[0].metadata[0].name : ""
          secretKey      = "rcon-password"
        }
      }

      resources = {
        requests = {
          memory = "${tonumber(trimsuffix(var.memory, "G")) + 1}G"
        }
      }

      extraEnv = {
        USE_MEOWICE_FLAGS = "true"
        PATCH_DEFINITIONS = "/patches"
      }

      persistence = {
        dataDir = {
          enabled = true
          Size    = var.disk_size
        }
      }

      mcbackup = {
        enabled = var.backups_enabled
        persistence = {
          backupDir = {
            enabled       = var.backups_enabled
            existingClaim = var.backups_enabled ? kubernetes_persistent_volume_claim_v1.backups[0].metadata[0].name : ""
          }
        }
      }

      serviceAnnotations = var.dns == null ? {} : {
        "external-dns.kubernetes.io/hostname" = "minecraft-svc.${var.dns.hostname}"
      }

      affinity = var.prefer_nodes != "" ? {
        nodeAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [
                  {
                    key      = split("=", var.prefer_nodes)[0]
                    operator = "In"
                    values   = [split("=", var.prefer_nodes)[1]]
                  }
                ]
              }
            }
          ]
        }
      } : {}

      extraVolumes = [
        {
          volumes = [{
            name = "prometheus-exporter-config"
            configMap = {
              name = kubernetes_config_map_v1.prometheus_exporter_config.metadata[0].name
            }
          }]
        },
        {
          volumes = [
            {
              name = "paper-patches"
              configMap = {
                name = "${var.server_id}-paper-patches"
              }
            }
          ]
          volumeMounts = [
            {
              name      = "paper-patches"
              mountPath = "/patches"
              readOnly  = true
            }
          ]
        }
      ]

      initContainers = [
        {
          name  = "init-prometheus-config"
          image = "busybox:latest"
          command = [
            "sh",
            "-c",
            "mkdir -p /data/plugins/PrometheusExporter && cp /tmp/prometheus-config/config.yml /data/plugins/PrometheusExporter/config.yml"
          ]
          volumeMounts = [
            {
              name      = "prometheus-exporter-config"
              mountPath = "/tmp/prometheus-config"
            },
            {
              name      = "datadir"
              mountPath = "/data"
            }
          ]
        }
      ]

      extraDeploy = [
        {
          apiVersion = "v1"
          kind       = "ConfigMap"
          metadata = {
            name = "${var.server_id}-paper-patches"
          }
          data = {
            "allow-piston-duplication.json" = jsonencode({
              file = "/data/config/paper-global.yml"
              ops = [
                {
                  "$set" = {
                    path  = "$.unsupported-settings.allow-piston-duplication"
                    value = true
                  }
                }
              ]
            })
          }
        }
      ]
    })
  ]
}

resource "hcloud_zone_rrset" "srv" {
  count = var.dns == null ? 0 : 1

  name = trimsuffix("_minecraft._tcp.${trimsuffix(var.dns.hostname, var.dns.zone.name)}", ".")
  type = "SRV"
  zone = var.dns.zone.id
  records = [
    {
      value = "0 0 ${var.port} minecraft-svc.${var.dns.hostname}."
    }
  ]
}

resource "kubernetes_config_map_v1" "prometheus_exporter_config" {
  metadata {
    name      = "${var.server_id}-minecraft-prometheus-config"
    namespace = resource.kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "config.yml" = <<-EOT
        # Note that the HTTP server binds to localhost by default.
        # If your Prometheus runs on another host or inside a Kubernetes cluster,
        # set this to any reachable IP or 0.0.0.0 to listen on all interfaces.
        #
        # These settings can be overridden by environment variables or system properties.
        # Environment variables:
        #   - MINECRAFT_PROMETHEUS_EXPORTER_HOST: Overrides the host setting (e.g., 0.0.0.0)
        #   - MINECRAFT_PROMETHEUS_EXPORTER_PORT: Overrides the port setting (e.g., 9001)
        #
        # System properties (set during JVM startup):
        #   -Dminecraft.prometheus.exporter.host=0.0.0.0
        #   -Dminecraft.prometheus.exporter.port=9001
        host: 0.0.0.0
        # The port can be changed in case it conflicts with any other application.
        port: 9940
        # Metrics can be enabled individually. Metrics which are disabled
        # by default may have a performance impact on your server.
        # See the rest of the README for more information.
        enable_metrics:
          jvm_threads: true
          jvm_gc: true
          players_total: true
          whitelisted_players: true
          entities_total: true
          living_entities_total: true
          loaded_chunks_total: true
          jvm_memory: true
          players_online_total: true
          tps: true
          tick_duration_average: true
          tick_duration_median: true
          tick_duration_min: false
          tick_duration_max: true
          player_online: true
          player_statistic: true
    EOT
  }
}

resource "kubernetes_manifest" "minecraft_pod_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "${var.server_id}-minecraft"
      namespace = resource.kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      # Selects the Minecraft pod created by the helm chart
      selector = {
        matchLabels = {
          "app.kubernetes.io/instance" = "${var.server_id}-minecraft"
          "app.kubernetes.io/name"     = "minecraft"
        }
      }
      podMetricsEndpoints = [
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "15s"
        }
      ]
    }
  }
}
