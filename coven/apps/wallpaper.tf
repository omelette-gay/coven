# Wallpaper Cropper, hosted on GitHub Pages from https://github.com/omelette-gay/wallpaper-cropper

resource "hcloud_zone_rrset" "wallpaper" {
  name = "wallpaper"
  type = "CNAME"
  zone = data.hcloud_zone.omelette_gay.id
  records = [
    { value = "omelette-gay.github.io." }
  ]
}
