terraform {
  required_version = ">= 1.9.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

# Lets nothing through: Traefik answers every request with a 403, as none come from inside its own pod
resource "kubernetes_manifest" "deny_all" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${var.name}-deny-all"
      namespace = var.namespace
    }
    spec = {
      ipAllowList = {
        sourceRange = ["127.0.0.1/32"]
      }
    }
  }
}

# A router for just the blocked paths, which wins over the service's own Ingress because of its higher priority. Its
# backend is Traefik's built-in noop service, so it doesn't depend on the service's name or port, and requests never
# reach the service even if the middleware were missing.
resource "kubernetes_manifest" "block_path" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        kind     = "Rule"
        match    = "Host(`${var.host}`) && PathRegexp(`${var.path_regexp}`)"
        priority = 10000
        middlewares = [{
          name = kubernetes_manifest.deny_all.manifest.metadata.name
        }]
        services = [{
          kind = "TraefikService"
          name = "noop@internal"
        }]
      }]
      tls = {
        secretName = var.tls_secret_name
      }
    }
  }
}
