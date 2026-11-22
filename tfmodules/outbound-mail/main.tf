terraform {
  # Write-only arguments need 1.11, and ephemeral resources 1.10
  required_version = ">= 1.11.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1.0"
    }
  }
}

resource "kubernetes_namespace_v1" "mail" {
  metadata {
    name = var.namespace
  }
}

locals {
  # the DKIM selector, and the name of the domain within its DNS zone (e.g. "coven")
  dkim_selector = "mail"
  dns_name      = var.dns_zone == null ? null : trimsuffix(trimsuffix(var.domain, var.dns_zone.name), ".")
}

# Generated when dkim_key_revision changes, and never stored in state: the private key goes to Vault for postfix, and the
# public key to a separate Vault secret, which is read back for the DNS record.
ephemeral "tls_private_key" "dkim" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

locals {
  dkim_public_key = ephemeral.tls_private_key.dkim.public_key_pem
  # the base64 key on one line, as DNS needs it
  dkim_public_key_value = replace(replace(replace(local.dkim_public_key, "-----BEGIN PUBLIC KEY-----", ""), "-----END PUBLIC KEY-----", ""), "\n", "")
}

resource "vault_kv_secret_v2" "dkim" {
  mount = var.vault_kv_mountpoint
  name  = "mail/dkim"

  # the file names opendkim looks for in the postfix chart
  data_json_wo = jsonencode({
    "${var.domain}.private" = ephemeral.tls_private_key.dkim.private_key_pem_pkcs8
    "${var.domain}.txt"     = "${local.dkim_selector}._domainkey\tIN\tTXT\t( \"v=DKIM1; k=rsa; p=${local.dkim_public_key_value}\" ) ; ----- DKIM key ${local.dkim_selector} for ${var.domain}"
  })
  data_json_wo_version = var.dkim_key_revision
}

resource "vault_kv_secret_v2" "dkim_public" {
  mount = var.vault_kv_mountpoint
  name  = "mail/dkim-public"

  data_json_wo         = jsonencode({ public_key = local.dkim_public_key_value })
  data_json_wo_version = var.dkim_key_revision
}

# Only the public key, so it's fine in state. Read at apply time when the key has just changed. This data source is
# deprecated in favour of the ephemeral one, but an ephemeral value can't be used in the DNS record.
data "vault_kv_secret_v2" "dkim_public" {
  count = var.dns_zone != null ? 1 : 0

  mount = var.vault_kv_mountpoint
  name  = vault_kv_secret_v2.dkim_public.name

  depends_on = [vault_kv_secret_v2.dkim_public]
}

module "dkim_key" {
  source = "../vault-k8s-secret"

  vault_secret_name             = vault_kv_secret_v2.dkim.name
  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
  k8s_secret_name               = "dkim"
  k8s_namespace                 = kubernetes_namespace_v1.mail.metadata[0].name
  k8s_service_account_name      = "outbound-mail-dkim"
  vault_role_name               = "outbound-mail-dkim"
}

resource "hcloud_zone_rrset" "dkim" {
  count = var.dns_zone != null ? 1 : 0

  zone = var.dns_zone.id
  name = "${local.dkim_selector}._domainkey.${local.dns_name}"
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=DKIM1; k=rsa; p=${data.vault_kv_secret_v2.dkim_public[0].data["public_key"]}") }
  ]
}

resource "hcloud_zone_rrset" "spf" {
  count = var.dns_zone != null ? 1 : 0

  zone = var.dns_zone.id
  name = local.dns_name
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=spf1 ${join(" ", [for address in var.ipv4_addresses : "ip4:${address}"])} ~all") }
  ]
}

resource "hcloud_zone_rrset" "dmarc" {
  count = var.dns_zone != null ? 1 : 0

  zone = var.dns_zone.id
  name = "_dmarc.${local.dns_name}"
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=DMARC1; p=quarantine") }
  ]
}

resource "helm_release" "mail" {
  name       = "mail"
  namespace  = kubernetes_namespace_v1.mail.metadata[0].name
  repository = "https://bokysan.github.io/docker-postfix"
  chart      = "mail"
  version    = "5.2.1"
  atomic     = true
  wait       = true

  values = [yamlencode(merge(
    {
      config = {
        general = { ALLOWED_SENDER_DOMAINS = var.domain }
        postfix = { myhostname = var.domain }
      }
      extraVolumes = [{
        name   = "dkim-keys"
        secret = { secretName = module.dkim_key.k8s_secret_name }
      }]
      extraVolumeMounts = [{
        name      = "dkim-keys"
        mountPath = "/etc/opendkim/keys"
        readOnly  = true
      }]
      metrics = {
        enabled        = true
        serviceMonitor = { enabled = true }
      }
    },
    length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {},
  ))]
}
