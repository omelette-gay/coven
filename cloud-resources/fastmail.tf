# delegate some domains to Chris's Fastmail account

locals {
  domains_with_fastmail_mx = {
    "animebots.co.uk"          = hcloud_zone.animebots_co_uk,
    "barcampmanchester.co.uk"  = hcloud_zone.barcampmanchester_co_uk,
    "chrisn.xyz"               = hcloud_zone.chrisn_xyz,
    "cjn.me.uk"                = hcloud_zone.cjn_me_uk,
    "dxhosting.co.uk"          = hcloud_zone.dxhosting_co_uk,
    "manchestertechnights.org" = hcloud_zone.manchestertechnights_org,
    "pling.org.uk"             = hcloud_zone.pling_org_uk,
  }
}

resource "hcloud_zone_rrset" "fastmail_mx" {
  for_each = local.domains_with_fastmail_mx

  name = "@"
  type = "MX"
  zone = each.value.id

  records = [
    { value = "10 in1-smtp.messagingengine.com." },
    { value = "20 in2-smtp.messagingengine.com." }
  ]
}

resource "hcloud_zone_rrset" "fastmail_spf" {
  for_each = local.domains_with_fastmail_mx

  name = "@"
  type = "TXT"
  zone = each.value.id
  records = [
    { value = provider::hcloud::txt_record("v=spf1 include:spf.messagingengine.com ?all") }
  ]
}

resource "hcloud_zone_rrset" "fastmail_dkim1" {
  for_each = local.domains_with_fastmail_mx

  name = "fm1._domainkey"
  type = "CNAME"
  zone = each.value.id
  records = [
    { value = "fm1.${each.value.name}.dkim.fmhosted.com." }
  ]
}

resource "hcloud_zone_rrset" "fastmail_dkim2" {
  for_each = local.domains_with_fastmail_mx

  name = "fm2._domainkey"
  type = "CNAME"
  zone = each.value.id
  records = [
    { value = "fm2.${each.value.name}.dkim.fmhosted.com." }
  ]
}

resource "hcloud_zone_rrset" "fastmail_dkim3" {
  for_each = local.domains_with_fastmail_mx

  name = "fm3._domainkey"
  type = "CNAME"
  zone = each.value.id
  records = [
    { value = "fm3.${each.value.name}.dkim.fmhosted.com." }
  ]
}

resource "hcloud_zone_rrset" "fastmail_dmarc" {
  for_each = local.domains_with_fastmail_mx

  name = "_dmarc"
  type = "TXT"
  zone = each.value.id
  records = [
    { value = provider::hcloud::txt_record("v=DMARC1; p=none;") }
  ]
}