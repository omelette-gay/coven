# omelette.gay is in the bootstrap stack, as some of its records are needed before the cluster is configured
data "hcloud_zone" "omelette_gay" {
  name = "omelette.gay"
}

resource "hcloud_zone" "animebots_co_uk" {
  name = "animebots.co.uk"
  mode = "primary"
}

resource "hcloud_zone" "barcampmanchester_co_uk" {
  name = "barcampmanchester.co.uk"
  mode = "primary"
}

resource "hcloud_zone" "chrisn_xyz" {
  name = "chrisn.xyz"
  mode = "primary"
}

resource "hcloud_zone" "dxhosting_co_uk" {
  name = "dxhosting.co.uk"
  mode = "primary"
}

resource "hcloud_zone" "manchestertechnights_org" {
  name = "manchestertechnights.org"
  mode = "primary"
}

resource "hcloud_zone" "moretobooks_com" {
  name = "moretobooks.com"
  mode = "primary"
}

resource "hcloud_zone" "pling_org_uk" {
  name = "pling.org.uk"
  mode = "primary"
}
