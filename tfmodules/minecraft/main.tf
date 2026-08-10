terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.68.0"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "minecraft-${var.server_id}"
  }
}

resource "helm_release" "minecraft" {
  name       = var.server_id
  namespace  = resource.kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://itzg.github.io/minecraft-server-charts/"
  chart      = "minecraft"
  version    = "5.1.3"
  values = [
    yamlencode({
      minecraftServer = {
        eula       = true
        difficulty = "normal"
        type       = "PAPER"
        whitelist  = join(",", var.whitelist)
        ops        = join(",", var.ops)
        motd       = var.motd

        plugin_urls = ["https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v3.1.2/minecraft-prometheus-exporter-3.1.2.jar"]

        serviceType = "LoadBalancer"
        servicePort = var.port

        memory = var.memory
        tty    = false
      }
      extraEnv = {
        USE_MEOWICE_FLAGS = "true"
      }
      persistence = {
        dataDir = {
          enabled = true
        }
      }
      serviceAnnotations = var.dns == null ? {} : {
        "external-dns.alpha.kubernetes.io/hostname" = "minecraft-svc.${var.dns.hostname}"
      }
      extraPorts = [
        {
          name          = "metrics"
          containerPort = 9940
          protocol      = "TCP"
          service = {
            enabled = false # do not expose to the world
          }
        }
      ]
      # Mount the ConfigMap into a temporary directory in the pod
      extraVolumes = [
        {
          volumes = {
            name = "prometheus-exporter-config"
            configMap = {
              name = kubernetes_config_map_v1.prometheus_exporter_config.metadata[0].name
            }
          }
          volumeMounts = [
            {
              name      = "prometheus-exporter-config"
              mountPath = "/tmp/prometheus-config"
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
