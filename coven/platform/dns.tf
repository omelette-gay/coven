# omelette.gay is in the bootstrap stack, as some of its records are needed before the cluster is configured
data "hcloud_zone" "omelette_gay" {
  name = "omelette.gay"
}

# Records for things external-dns doesn't manage, as they aren't ingresses: the machines themselves
locals {
  machine_records = {
    strix_a     = { name = "strix.xdc", type = "A", value = "168.119.4.112" }
    strix_aaaa  = { name = "strix.xdc", type = "AAAA", value = "2a01:4f8:242:4f21::2" }
    janus_a     = { name = "janus.gs", type = "A", value = "51.148.152.196" }
    janus_aaaa  = { name = "janus.gs", type = "AAAA", value = "2a02:8011:d017:dba5::1" }
    grimhilde_a = { name = "grimhilde.gs", type = "A", value = "192.168.178.36" }
  }
}

resource "hcloud_zone_rrset" "machine" {
  for_each = local.machine_records

  zone    = data.hcloud_zone.omelette_gay.id
  name    = each.value.name
  type    = each.value.type
  records = [{ value = each.value.value }]
}
