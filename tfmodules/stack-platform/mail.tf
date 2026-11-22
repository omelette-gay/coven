# Postfix, which apps in the cluster send mail through. Where there's public DNS, its DKIM, SPF and DMARC records are
# published for cluster_domain.
module "outbound_mail" {
  source = "../outbound-mail"

  domain            = var.cluster_domain
  dns_zone          = var.dns_zone
  ipv4_addresses    = var.mail_ipv4_addresses
  node_selector     = var.outbound_mail_node_selector
  dkim_key_revision = var.dkim_key_revision

  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
}
