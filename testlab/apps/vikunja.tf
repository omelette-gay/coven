# Disabled to save memory on the single-node testlab. Uncomment it to test changes to tfmodules/vikunja.
# module "vikunja" {
#   source = "../../tfmodules/vikunja"
#
#   host           = "tasks.coven.local"
#   cluster_issuer = "vault"
#   keycloak_url   = "https://auth.coven.local/auth"
#   keycloak_realm = "omelette.gay"
#   sender_email   = "vikunja@coven.local"
#   smtp_host      = "mail.mail.svc.cluster.local"
#   smtp_port      = 587
#   blackbox_prober = {
#     url  = "blackbox-exporter-prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115"
#     path = "/probe"
#   }
#
#   # The testlab has a single node, so a standby wouldn't add anything
#   postgresql_instances = 1
#
#   # Installed by the bootstrap stack
#   postgresql_image_catalog = "postgresql"
#
#   # Keep the testlab's backups apart from coven's, which will use /cnpg/vikunja/
#   backup_path = "/testlab/cnpg/vikunja/"
#
#   # Cluster DNS can't resolve the testlab's Keycloak, and its certificate is from Vault's CA, which the ingress
#   # certificate's Secret carries in ca.crt
#   host_aliases           = [{ ip = "192.168.57.100", hostnames = ["auth.coven.local"] }]
#   trusted_ca_secret_name = "vikunja-tls"
# }
