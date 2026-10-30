terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
  }
}

# Traefik ignores an Ingress whose backend service doesn't exist, so the Ingresses point at this service, which has no
# pods behind it. The redirect middleware answers every request before it gets that far.
resource "kubernetes_service_v1" "noop" {
  metadata {
    name      = "noop"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_manifest" "redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "redirect"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      redirectRegex = {
        regex       = ".*"
        replacement = var.redirect_target
        permanent   = true
      }
    }
  }
}

resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd,${kubernetes_namespace_v1.this.metadata[0].name}-${kubernetes_manifest.redirect.manifest.metadata.name}@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    dynamic "rule" {
      for_each = var.hostnames

      content {
        host = rule.value
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service_v1.noop.metadata[0].name
                port {
                  name = "http"
                }
              }
            }
          }
        }
      }
    }

    # one certificate covering every hostname
    tls {
      hosts       = var.hostnames
      secret_name = "${var.name}-tls"
    }
  }
}
