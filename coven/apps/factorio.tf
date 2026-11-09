module "girlsclub_factorio" {
  source = "../../tfmodules/factorio"

  server_id = "girlsclub"
  port      = 31497
  dns = {
    hostname = "omelette.gay"
    zone     = data.hcloud_zone.omelette_gay
  }

  save_name          = "girls-club"
  server_name        = "Girls go Space"
  description        = "Just doing girls things, in space"
  password_protected = true

  preferred_node_labels       = local.game_server_preferred_node
  memory                      = "3Gi"
  disk_size                   = "2Gi"
  longhorn_recurring_job_name = local.nightly_backup_job
}

module "chegsworld_factorio" {
  source = "../../tfmodules/factorio"

  server_id = "chegsworld"
  port      = 31495
  dns = {
    hostname = "chegsworld.omelette.gay"
    zone     = data.hcloud_zone.omelette_gay
  }

  save_name          = "chegsworld"
  server_name        = "Chegs World"
  description        = "Making a factory a home"
  password_protected = true

  preferred_node_labels       = local.game_server_preferred_node
  memory                      = "1.5Gi"
  longhorn_recurring_job_name = local.nightly_backup_job
}
