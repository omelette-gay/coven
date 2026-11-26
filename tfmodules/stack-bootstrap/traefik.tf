# Traefik is installed by k3s, whose CRDs exist before this stack is applied, so these can use kubernetes_manifest.

# Traefik's metrics, and the blockpath plugin. Services in this repo use the traefik-block-path module instead, as
# Traefik only downloads plugins when it starts and turns them off for good if that fails (issue #141). The plugin stays
# until the self-deploying apps that still use it (Home Assistant and virtualflightonlinetransmitter) have moved off it.
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

# Redirects HTTP to HTTPS, for every ingress to use
resource "kubernetes_manifest" "redirect_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "redirect-https"
      namespace = "kube-system"
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }
}
