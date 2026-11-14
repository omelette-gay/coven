# GitHub verification and Pages sites for the omelette-gay organisation

resource "hcloud_zone_rrset" "github_org_verification" {
  name = "_gh-omelette-gay-o"
  type = "TXT"
  zone = data.hcloud_zone.omelette_gay.id
  records = [
    { value = provider::hcloud::txt_record("003bfe87d7") }
  ]
}

# https://github.com/omelette-gay/wallpaper-cropper
resource "hcloud_zone_rrset" "wallpaper" {
  name = "wallpaper"
  type = "CNAME"
  zone = data.hcloud_zone.omelette_gay.id
  records = [
    { value = "omelette-gay.github.io." }
  ]
}
