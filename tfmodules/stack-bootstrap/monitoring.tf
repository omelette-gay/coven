resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "monitoring"
    }
  }
}

# The Prometheus Operator's CRDs, on their own so they can be installed before Longhorn, whose ServiceMonitor needs them,
# while kube-prometheus-stack needs Longhorn for its volumes. Keep this in step with the operator version of
# kube-prometheus-stack below: the CRDs must never be older than the chart (Renovate groups their major updates). The
# chart keeps the CRDs if the release is ever deleted.
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  version    = "33.0.2"
  atomic     = true
  wait       = true

  # kube-prometheus-stack's upgrade job installed the CRDs before this release existed
  take_ownership = true
}

# Controller nodes, whose addresses kube-prometheus-stack scrapes for the k3s components that run inside the k3s
# process rather than as pods
data "kubernetes_nodes" "controllers" {
  metadata {
    labels = {
      "node-role.kubernetes.io/control-plane" = "true"
    }
  }
}

locals {
  controller_ips = sort([
    for node in data.kubernetes_nodes.controllers.nodes :
    one([for address in node.status[0].addresses : address.address if address.type == "InternalIP"])
  ])
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "93.3.0"
  atomic     = true
  wait       = true
  timeout    = 900

  values = [templatefile("${path.module}/values/kube-prometheus-stack.yaml.tftpl", {
    cluster_domain     = var.cluster_domain
    cluster_issuer     = var.cluster_issuer
    grafana_host       = local.grafana_host
    keycloak_realm_url = "${local.keycloak_url}/realms/omelette.gay"
    insecure_tls       = var.cluster_issuer == "vault"
    smtp_relay         = local.smtp_relay
    host_aliases       = var.host_aliases
    controller_ips     = local.controller_ips
  })]

  depends_on = [helm_release.prometheus_operator_crds, helm_release.longhorn]
}

resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
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

  depends_on = [helm_release.prometheus_operator_crds]
}

resource "helm_release" "helm_exporter" {
  name       = "helm-exporter"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://shanestarcher.com/helm-charts/"
  chart      = "helm-exporter"
  version    = "1.4.0+e2eee28"
  atomic     = true
  wait       = true

  values = [yamlencode({
    serviceMonitor   = { create = true }
    grafanaDashboard = { enabled = true }
  })]

  depends_on = [helm_release.prometheus_operator_crds]
}

# Traefik is installed by k3s, and configured through this k3s custom resource: metrics, and the blockpath plugin that
# the services here use to hide their metrics endpoints from the web. The CRD comes with k3s, so it exists before this
# stack is applied.
resource "kubernetes_manifest" "traefik_config" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      # chomp keeps the text exactly as Ansible wrote it, so Traefik isn't redeployed
      valuesContent = chomp(<<-EOT
        additionalArguments:
          - "--api.dashboard=true"
          - "--api.insecure=true"
          - "--providers.kubernetesingress.allowemptyservices=true"

        experimental:
          plugins:
            plugin-blockpath:
              moduleName: github.com/traefik/plugin-blockpath
              version: v0.2.1

        metrics:
          prometheus:
            enabled: true
            serviceMonitor:
              enabled: true
      EOT
      )
    }
  }
}
