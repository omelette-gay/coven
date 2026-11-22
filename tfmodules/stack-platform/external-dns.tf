# Keeps public DNS in Hetzner in step with the cluster's ingresses. Only where there's public DNS (not the testlab).
module "external_dns" {
  source = "../external-dns"
  count  = var.dns_zone != null ? 1 : 0

  txt_owner_id = var.cluster_domain

  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
}
