# Task lists and kanban boards, replacing Planka (#592)
module "vikunja" {
  source = "../../tfmodules/vikunja"

  domain       = "tasks.omelette.gay"
  keycloak_url = "${local.keycloak_url}${local.keycloak_base_path}"
  sender_email = "vikunja@coven.omelette.gay"

  # Must be set on first deploy: adding it later moves attachments to a new, empty volume
  longhorn_recurring_job_name = local.nightly_backup_job
}
