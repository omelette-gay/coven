terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
  }
}

resource "hcloud_zone_rrset" "organisation" {
  name = "_gh-${var.organisation}-o"
  type = "TXT"
  zone = var.zone.id
  records = [
    { value = provider::hcloud::txt_record(var.verification_code) }
  ]
}

resource "hcloud_zone_rrset" "pages" {
  count = var.pages_verification_code == null ? 0 : 1

  name = "_github-pages-challenge-${var.organisation}"
  type = "TXT"
  zone = var.zone.id
  records = [
    { value = provider::hcloud::txt_record(var.pages_verification_code) }
  ]
}
