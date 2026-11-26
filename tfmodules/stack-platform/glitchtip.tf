module "glitchtip" {
  source = "../glitchtip"

  host                     = var.glitchtip_host
  cluster_issuer           = var.cluster_issuer
  keycloak_url             = var.keycloak_url
  keycloak_secret_revision = var.glitchtip_keycloak_secret_revision
  postgresql_instances     = var.glitchtip_postgresql_instances
  postgresql_image_catalog = var.postgresql_image_catalog
  sender_email             = var.glitchtip_sender_email
  keycloak_realm           = keycloak_realm.omelette_gay.realm
  smtp_host                = module.outbound_mail.smtp_host
  smtp_port                = module.outbound_mail.smtp_port
  blackbox_prober          = local.blackbox_prober

  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
}
