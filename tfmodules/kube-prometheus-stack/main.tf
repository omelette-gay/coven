terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
  }
}

locals {
  # Drop the high-cardinality histograms we don't use from the k3s components' metrics. k3s runs them all in one process
  # and exposes them together, so each scrape gets all of them
  # (https://github.com/k3s-io/k3s/issues/3619#issuecomment-1991598167).
  k3s_metric_drops = [
    for regex in [
      "(apiserver_request_duration_seconds_bucket|apiserver_request_body_size_bytes_bucket|apiserver_response_sizes_bucket|apiserver_watch_events_sizes_bucket|apiserver_request_sli_duration_seconds_bucket)",
      "etcd_request_duration_seconds_bucket",
      "(scheduler_plugin_execution_duration_seconds_bucket)",
      "(workqueue_work_duration_seconds_bucket)",
    ] : { action = "drop", regex = regex, sourceLabels = ["__name__"] }
  ]

  # The k3s components that kube-prometheus-stack scrapes. There's no etcd, as k3s uses its own datastore.
  k3s_components = {
    kubeApiServer = {
      serviceMonitor = { metricRelabelings = local.k3s_metric_drops }
    }
    kubelet = {
      serviceMonitor = {
        cAdvisorRelabelings = [
          { action = "replace", sourceLabels = ["__metrics_path__"], targetLabel = "metrics_path" },
          { action = "replace", targetLabel = "instance", sourceLabels = ["node"] },
        ]
        relabelings = [
          { action = "replace", sourceLabels = ["__metrics_path__"], targetLabel = "metrics_path" },
        ]
        metricRelabelings = local.k3s_metric_drops
      }
    }
    kubeControllerManager = {
      endpoints      = var.controller_ips
      serviceMonitor = { https = true, metricRelabelings = local.k3s_metric_drops }
    }
    kubeScheduler = {
      endpoints      = var.controller_ips
      serviceMonitor = { https = true, metricRelabelings = local.k3s_metric_drops }
    }
    kubeProxy = {
      endpoints      = var.controller_ips
      service        = { selector = { k8s-app = "kube-proxy" } }
      serviceMonitor = { metricRelabelings = local.k3s_metric_drops }
    }
    coreDns = {
      serviceMonitor = { metricRelabelings = local.k3s_metric_drops }
    }
    kubeDns = {
      serviceMonitor = { metricRelabelings = local.k3s_metric_drops }
    }
  }

  # Our own alert rules, one file per group in values/alerts/, named after the file
  alert_rules = {
    for file in fileset("${path.module}/values/alerts", "*.yaml") :
    trimsuffix(file, ".yaml") => yamldecode(file("${path.module}/values/alerts/${file}"))
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  # Keep the Prometheus Operator CRDs in step with this (see the README)
  version = "93.3.0"
  atomic  = true
  wait    = true
  timeout = 900

  # Helm merges these in order. None of them set the same keys.
  values = [
    # the CRDs are installed separately, before Longhorn, which needs them (see the README)
    yamlencode({ crds = { enabled = false } }),
    templatefile("${path.module}/values/grafana.yaml.tftpl", {
      grafana_host       = var.grafana_host
      cluster_issuer     = var.cluster_issuer
      keycloak_realm_url = var.keycloak_realm_url
      insecure_tls       = var.insecure_tls
      smtp_relay         = "${var.smtp_host}:${var.smtp_port}"
      oauth_secret       = var.grafana_oauth_secret
      cluster_domain     = var.cluster_domain
      host_aliases       = var.host_aliases
    }),
    file("${path.module}/values/prometheus.yaml"),
    yamlencode(local.k3s_components),
    file("${path.module}/values/node-exporter.yaml"),
    templatefile("${path.module}/values/alertmanager.yaml.tftpl", {
      smtp_relay     = "${var.smtp_host}:${var.smtp_port}"
      cluster_domain = var.cluster_domain
    }),
    file("${path.module}/values/kube-state-metrics.yaml"),
    yamlencode({ additionalPrometheusRulesMap = local.alert_rules }),
  ]
}

# Probes our sites over HTTPS, from blackbox Probe resources (see local.blackbox_prober in the platform stack)
resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = "11.21.3"
  atomic     = true
  wait       = true

  values = [yamlencode({
    serviceMonitor = {
      enabled     = true
      selfMonitor = { enabled = true }
    }
  })]
}

# Reports the state of every Helm release, for the HelmRelease* alerts
resource "helm_release" "helm_exporter" {
  name       = "helm-exporter"
  namespace  = var.namespace
  repository = "https://shanestarcher.com/helm-charts"
  chart      = "helm-exporter"
  version    = "1.4.0+e2eee28"
  atomic     = true
  wait       = true

  values = [yamlencode({
    serviceMonitor   = { create = true }
    grafanaDashboard = { enabled = true }
  })]
}
