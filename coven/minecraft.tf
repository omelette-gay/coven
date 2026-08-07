module "girlsclub_minecraft" {
  source = "../tfmodules/minecraft"

  server_id = "girlsclub"
  port      = 21585
  dns = {
    hostname = "omelette.gay"
    zone     = hcloud_zone.omelette_gay
  }

  motd = "Girls yearn for the mines"
  whitelist = [
    "DizzyUK83"
  ]
  ops = [
    "DizzyUK83"
  ]
}
