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

resource "kubernetes_namespace_v1" "trivy_system" {
  metadata {
    name = "trivy-system"
  }
}

resource "helm_release" "trivy_operator" {
  name             = "trivy-operator"
  repository       = "https://aquasecurity.github.io/helm-charts"
  chart            = "trivy-operator"
  version          = "0.38.1"
  namespace        = kubernetes_namespace_v1.trivy_system.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      serviceMonitor = {
        enabled = true
      }
      operator = {
        scanJobsConcurrentLimit = 2
        builtInTrivyServer      = true
      }
      trivy = {
        # Only report vulnerabilities that have a fixed version available, so the reports list things an image
        # update can actually clear, rather than CVEs nobody can act on yet
        ignoreUnfixed = true
      }
    })
  ]
}
