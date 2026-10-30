# zones for other domains are in the apps stack, alongside what uses them
resource "hcloud_zone" "omelette_gay" {
  name = "omelette.gay"
  mode = "primary"

  lifecycle {
    prevent_destroy = true
  }
}
