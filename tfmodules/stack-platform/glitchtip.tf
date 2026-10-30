module "glitchtip" {
  source = "../glitchtip"

  domain               = var.glitchtip_domain
  cluster_issuer       = var.cluster_issuer
  keycloak_url         = var.keycloak_url
  postgresql_instances = var.glitchtip_postgresql_instances
  sender_email         = var.glitchtip_sender_email

  existing_secrets = var.glitchtip_existing_secrets
}
