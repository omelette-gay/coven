# Task lists and kanban boards
module "vikunja" {
  source = "../../tfmodules/vikunja"

  host            = "tasks.omelette.gay"
  cluster_issuer  = "letsencrypt"
  keycloak_url    = "${local.keycloak_url}${local.keycloak_base_path}"
  keycloak_realm  = local.keycloak_realm
  sender_email    = "vikunja@coven.omelette.gay"
  smtp_host       = local.smtp_host
  smtp_port       = local.smtp_port
  blackbox_prober = local.blackbox_prober

  # Must be set on first deploy: adding it later moves attachments to a new, empty volume
  longhorn_recurring_job_name = local.nightly_backup_job
  postgresql_image_catalog    = local.postgresql_image_catalog
}
