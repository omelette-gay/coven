# Postfix, which apps in the cluster send mail through (mail.mail.svc.cluster.local:587). It signs mail with DKIM, and
# on coven its DKIM, SPF and DMARC records are published for cluster_domain.
resource "kubernetes_namespace_v1" "mail" {
  metadata {
    name = "mail"
  }
}

locals {
  # the DKIM selector, and the name of cluster_domain within the omelette.gay zone (e.g. "coven")
  dkim_selector = "mail"
  mail_dns_name = trimsuffix(trimsuffix(var.cluster_domain, "omelette.gay"), ".")
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
  mount = "secret"
  name  = "mail/dkim"

  # the file names opendkim looks for in the postfix chart
  data_json_wo = jsonencode({
    "${var.cluster_domain}.private" = ephemeral.tls_private_key.dkim.private_key_pem_pkcs8
    "${var.cluster_domain}.txt"     = "${local.dkim_selector}._domainkey\tIN\tTXT\t( \"v=DKIM1; k=rsa; p=${local.dkim_public_key_value}\" ) ; ----- DKIM key ${local.dkim_selector} for ${var.cluster_domain}"
  })
  data_json_wo_version = var.dkim_key_revision
}

resource "vault_kv_secret_v2" "dkim_public" {
  mount = "secret"
  name  = "mail/dkim-public"

  data_json_wo         = jsonencode({ public_key = local.dkim_public_key_value })
  data_json_wo_version = var.dkim_key_revision
}

# Only the public key, so it's fine in state. Read at apply time when the key has just changed. This data source is
# deprecated in favour of the ephemeral one, but an ephemeral value can't be used in the DNS record.
data "vault_kv_secret_v2" "dkim_public" {
  count = var.dns.enabled ? 1 : 0

  mount = "secret"
  name  = vault_kv_secret_v2.dkim_public.name

  depends_on = [vault_kv_secret_v2.dkim_public]
}

module "dkim_key" {
  source = "../vault-k8s-secret"

  vault_secret_name        = vault_kv_secret_v2.dkim.name
  k8s_secret_name          = "dkim"
  k8s_namespace            = kubernetes_namespace_v1.mail.metadata[0].name
  k8s_service_account_name = "outbound-mail-dkim"
  vault_role_name          = "outbound-mail-dkim"
}

resource "hcloud_zone_rrset" "dkim" {
  count = var.dns.enabled ? 1 : 0

  zone = local.omelette_gay_zone_id
  name = "${local.dkim_selector}._domainkey.${local.mail_dns_name}"
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=DKIM1; k=rsa; p=${data.vault_kv_secret_v2.dkim_public[0].data["public_key"]}") }
  ]
}

resource "hcloud_zone_rrset" "spf" {
  count = var.dns.enabled ? 1 : 0

  zone = local.omelette_gay_zone_id
  name = local.mail_dns_name
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=spf1 ${join(" ", [for address in var.dns.mail_ipv4_addresses : "ip4:${address}"])} ~all") }
  ]
}

resource "hcloud_zone_rrset" "dmarc" {
  count = var.dns.enabled ? 1 : 0

  zone = local.omelette_gay_zone_id
  name = "_dmarc.${local.mail_dns_name}"
  type = "TXT"
  records = [
    { value = provider::hcloud::txt_record("v=DMARC1; p=quarantine") }
  ]
}

resource "helm_release" "mail" {
  name       = "mail"
  namespace  = kubernetes_namespace_v1.mail.metadata[0].name
  repository = "https://bokysan.github.io/docker-postfix/"
  chart      = "mail"
  version    = "5.2.1"
  atomic     = true
  wait       = true

  values = [yamlencode(merge(
    {
      config = {
        general = { ALLOWED_SENDER_DOMAINS = var.cluster_domain }
        postfix = { myhostname = var.cluster_domain }
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
    length(var.outbound_mail_node_selector) > 0 ? { nodeSelector = var.outbound_mail_node_selector } : {},
  ))]
}
