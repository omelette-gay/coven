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

locals {
  # The chart's Service sends port 80 to this port on the pod, so the listener has to use it
  listen_port = 4000

  resource_url          = "https://${var.host}${var.path}"
  resource_metadata_url = "/.well-known/oauth-protected-resource${var.path}"

  config = {
    binds = [{
      port = local.listen_port
      listeners = [{
        routes = [{
          matches = [
            { path = { exact = var.path } },
            { path = { exact = local.resource_metadata_url } },
          ]
          backends = [{
            mcp = {
              targets = [{
                name = var.name
                mcp  = { host = var.upstream_url }
              }]
            }
          }]
          policies = {
            # Checks the caller's access token against the issuer's keys, and serves the protected resource metadata
            # that tells MCP clients where to log in
            mcpAuthentication = {
              mode      = "strict"
              issuer    = var.oidc_issuer
              audiences = [local.resource_url]
              jwks      = { url = var.oidc_jwks_url }
              resourceMetadata = {
                resource               = local.resource_url
                scopesSupported        = var.scopes_supported
                bearerMethodsSupported = ["header"]
              }
            }
            # Without the claim there's no credential to send upstream, so refuse rather than forward the request
            # with none
            authorization = {
              rules = [{ require = "has(jwt.${var.credential_claim})" }]
            }
            # Replaces the caller's access token with their credential for the upstream
            transformations = {
              request = {
                set = {
                  authorization = "\"Bearer \" + jwt.${var.credential_claim}"
                }
              }
            }
          }
        }]
      }]
    }]
  }
}

# Encrypts the MCP session IDs the gateway hands to clients. Without it they're plain base64 JSON that a client could
# read or forge, including the upstream address, and sessions don't survive the pod restarting. Vault paths and roles
# are global, so they're named after the namespace as well as the gateway
module "session_key" {
  source = "../generated-secret"

  hex_keys                 = { key = 32 }
  vault_secret_name        = "${var.namespace}/${var.name}-session-key"
  k8s_secret_name          = "${var.name}-session-key"
  k8s_namespace            = var.namespace
  k8s_service_account_name = "${var.name}-session-key"
  vault_role_name          = "${var.namespace}-${var.name}-session-key"
}

resource "helm_release" "agentgateway" {
  name       = var.name
  namespace  = var.namespace
  repository = "oci://cr.agentgateway.dev/charts"
  chart      = "agentgateway-standalone"
  version    = "v1.7.0"
  atomic     = true
  wait       = true

  values = [
    yamlencode({
      gateway = {
        service = {
          # Reached through the ingress below, not a load balancer of its own
          type = "ClusterIP"
        }
      }
      monitoring = {
        enabled = true
      }
      session = {
        secretName = module.session_key.k8s_secret_name
      }
      config = local.config
    })
  ]
}

# Only the MCP endpoint and its metadata go to the gateway. Traefik prefers the longer path, so these win over an
# ingress for the whole host
resource "kubernetes_ingress_v1" "agentgateway" {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.middlewares" = "kube-system-redirect-https@kubernetescrd"
    }
  }

  spec {
    tls {
      hosts       = [var.host]
      secret_name = var.tls_secret_name
    }

    rule {
      host = var.host
      http {
        dynamic "path" {
          for_each = [var.path, local.resource_metadata_url]
          content {
            path      = path.value
            path_type = "Exact"
            backend {
              service {
                name = helm_release.agentgateway.name
                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }
}
