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
  version          = "0.35.0"
  namespace        = kubernetes_namespace_v1.trivy_system.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      serviceMonitor = {
        enabled = true
      }
      operator = {
        concurrentScanJobsLimit = 2
      }
    })
  ]
}
