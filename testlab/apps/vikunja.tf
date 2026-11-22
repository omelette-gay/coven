module "vikunja" {
  source = "../../tfmodules/vikunja"

  domain         = "tasks.coven.local"
  cluster_issuer = "vault"
  keycloak_url   = "https://auth.coven.local/auth"
  sender_email   = "vikunja@coven.local"

  # The testlab has a single node, so a standby wouldn't add anything
  postgresql_instances = 1

  # Keep the testlab's backups apart from coven's, which will use /cnpg/vikunja/
  backup_path = "/testlab/cnpg/vikunja/"

  # Cluster DNS can't resolve the testlab's Keycloak, and its certificate is from Vault's CA, which the ingress
  # certificate's Secret carries in ca.crt
  host_aliases           = { "192.168.57.100" = ["auth.coven.local"] }
  trusted_ca_secret_name = "vikunja-tls"
}
