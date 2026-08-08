terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
  }
}

resource "hcloud_zone_rrset" "mx" {
  name = "@"
  type = "MX"
  zone = var.zone.id

  records = [
    { value = "10 in1-smtp.messagingengine.com." },
    { value = "20 in2-smtp.messagingengine.com." }
  ]
}

resource "hcloud_zone_rrset" "spf" {
  name = "@"
  type = "TXT"
  zone = var.zone.id
  records = [
    { value = provider::hcloud::txt_record("v=spf1 include:spf.messagingengine.com ?all") }
  ]
}

resource "hcloud_zone_rrset" "dkim" {
  for_each = toset(["fm1", "fm2", "fm3"])

  name = "${each.key}._domainkey"
  type = "CNAME"
  zone = var.zone.id
  records = [
    { value = "${each.key}.${var.zone.name}.dkim.fmhosted.com." }
  ]
}

resource "hcloud_zone_rrset" "dmarc" {
  name = "_dmarc"
  type = "TXT"
  zone = var.zone.id
  records = [
    { value = provider::hcloud::txt_record("v=DMARC1; p=none;") }
  ]
}
