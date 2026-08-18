module "girlsclub_minecraft" {
  source = "../tfmodules/minecraft"

  server_id = "girlsclub"
  port      = 21585
  dns = {
    hostname = "omelette.gay"
    zone     = hcloud_zone.omelette_gay
  }

  memory    = "4G"
  disk_size = "10G"

  backups_enabled             = true
  backup_disk_size            = "20G"
  longhorn_recurring_job_name = "nightly-backup"

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
