# Keeps public DNS in Hetzner in step with the cluster's ingresses. Coven only, as the testlab has no public DNS.
resource "kubernetes_namespace_v1" "external_dns" {
  count = var.dns.enabled ? 1 : 0

  metadata {
    name = "external-dns"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "external-dns"
    }
  }
}

module "external_dns_hetzner_token" {
  source = "../vault-k8s-secret"
  count  = var.dns.enabled ? 1 : 0

  vault_secret_name        = "gitops/hetzner"
  k8s_secret_name          = "hetzner"
  k8s_namespace            = kubernetes_namespace_v1.external_dns[0].metadata[0].name
  k8s_service_account_name = "hetzner-secret-reader"
  vault_role_name          = "hetzner-hetzner"
}

resource "helm_release" "external_dns" {
  count = var.dns.enabled ? 1 : 0

  name       = "hetzner"
  namespace  = kubernetes_namespace_v1.external_dns[0].metadata[0].name
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.24.0"
  atomic     = true
  wait       = true

  values = [yamlencode({
    policy = "sync"
    provider = {
      name = "webhook"
      webhook = {
        image = {
          repository = "docker.io/hetzner/external-dns-hetzner-webhook"
          tag        = local.external_dns_webhook_tag
        }
        env = [{
          name = "HETZNER_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = module.external_dns_hetzner_token[0].k8s_secret_name
              key  = "api_token"
            }
          }
        }]
      }
    }
    serviceMonitor = { enabled = true }
    # external-dns only changes records whose ownership TXT records carry this
    txtOwnerId = var.cluster_domain
  })]
}

locals {
  # renovate: datasource=docker depName=docker.io/hetzner/external-dns-hetzner-webhook
  external_dns_webhook_tag = "v0.5.1"
}

# Records for things that aren't ingresses, such as the machines themselves
resource "hcloud_zone_rrset" "extra" {
  for_each = var.dns.enabled ? var.dns.extra_records : {}

  zone    = local.omelette_gay_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [for value in each.value.values : { value = value }]
}
