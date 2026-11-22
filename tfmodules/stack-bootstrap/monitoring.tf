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
# kube-prometheus-stack (tfmodules/kube-prometheus-stack): the CRDs must never be older than the chart (Renovate groups their major updates). The
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

module "kube_prometheus_stack" {
  source = "../kube-prometheus-stack"

  namespace          = kubernetes_namespace_v1.monitoring.metadata[0].name
  cluster_domain     = var.cluster_domain
  grafana_host       = var.grafana_host
  cluster_issuer     = var.cluster_issuer
  keycloak_realm_url = "https://${var.keycloak_host}/auth/realms/${var.keycloak_realm}"
  insecure_tls       = var.insecure_tls
  smtp_relay         = var.smtp_relay
  host_aliases       = var.host_aliases
  controller_ips     = local.controller_ips

  # Prometheus, Alertmanager and Grafana's volumes must get Longhorn's storage class, which is the default only once
  # Longhorn is installed
  depends_on = [helm_release.prometheus_operator_crds, module.longhorn]
}
