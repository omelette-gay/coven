module "girlsclub_minecraft" {
  source = "../../tfmodules/minecraft"

  server_id = "girlsclub"
  port      = 21585
  dns = {
    hostname = "omelette.gay"
    zone     = data.hcloud_zone.omelette_gay
  }
  preferred_node_labels = local.game_server_preferred_node

  memory    = "4G"
  disk_size = "10Gi"

  backups_enabled             = true
  backup_disk_size            = "20Gi"
  longhorn_recurring_job_name = local.nightly_backup_job

  motd = "Girls yearn for the mines"
  whitelist = [
    "DizzyUK83",
    "Laser2k13",
    "Katie_Armitage",
    "emilyg99",
    "Christinana_",
    "WiFiGirl92",
    "slimsadie12345",
    "avakf",
    "Mystic_Liv",
    "PaddyHasCake"
  ]
  ops = [
    "DizzyUK83",
    "Laser2k13"
  ]
}
