module "glitchtip" {
  source = "../glitchtip"

  domain                   = var.glitchtip_domain
  cluster_issuer           = var.cluster_issuer
  keycloak_url             = var.keycloak_url
  keycloak_secret_revision = var.glitchtip_keycloak_secret_revision
  postgresql_instances     = var.glitchtip_postgresql_instances
  sender_email             = var.glitchtip_sender_email
}
