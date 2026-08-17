# delegate some domains to Chris's Fastmail account

module "fastmail" {
  source = "../tfmodules/fastmail"

  for_each = {
    for zone in [
      hcloud_zone.animebots_co_uk,
      hcloud_zone.barcampmanchester_co_uk,
      hcloud_zone.chrisn_xyz,
      hcloud_zone.cjn_me_uk,
      hcloud_zone.dxhosting_co_uk,
      hcloud_zone.manchestertechnights_org,
      hcloud_zone.pling_org_uk,
    ] : zone.name => zone
  }

  zone = each.value
}
