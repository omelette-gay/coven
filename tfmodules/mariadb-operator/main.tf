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

resource "kubernetes_namespace_v1" "mariadb" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

resource "helm_release" "mariadb_operator_crds" {
  name       = "mariadb-operator-crds"
  namespace  = kubernetes_namespace_v1.mariadb.metadata[0].name
  repository = "https://helm.mariadb.com/mariadb-operator"
  chart      = "mariadb-operator-crds"
  version    = "26.10.2"
  atomic     = true
  wait       = true
}

resource "helm_release" "mariadb_operator" {
  name       = "mariadb-operator"
  namespace  = kubernetes_namespace_v1.mariadb.metadata[0].name
  repository = "https://helm.mariadb.com/mariadb-operator"
  chart      = "mariadb-operator"
  version    = "26.10.2"
  atomic     = true
  wait       = true

  values = [yamlencode({
    metrics = { enabled = true }
    webhook = {
      cert = {
        certManager = {
          enabled = true
          issuerRef = {
            name = var.cluster_issuer
            kind = "ClusterIssuer"
          }
        }
      }
    }
  })]

  depends_on = [helm_release.mariadb_operator_crds]
}
