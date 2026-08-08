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

# Migration of the Fastmail records into ../tfmodules/fastmail.
# Safe to delete once this has been applied against all state files.

moved {
  from = hcloud_zone_rrset.fastmail_mx["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["animebots.co.uk"]
  to   = module.fastmail["animebots.co.uk"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["barcampmanchester.co.uk"]
  to   = module.fastmail["barcampmanchester.co.uk"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["chrisn.xyz"]
  to   = module.fastmail["chrisn.xyz"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["cjn.me.uk"]
  to   = module.fastmail["cjn.me.uk"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["dxhosting.co.uk"]
  to   = module.fastmail["dxhosting.co.uk"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["manchestertechnights.org"]
  to   = module.fastmail["manchestertechnights.org"].hcloud_zone_rrset.dkim["fm3"]
}

moved {
  from = hcloud_zone_rrset.fastmail_mx["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.mx
}

moved {
  from = hcloud_zone_rrset.fastmail_spf["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.spf
}

moved {
  from = hcloud_zone_rrset.fastmail_dmarc["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.dmarc
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim1["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.dkim["fm1"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim2["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.dkim["fm2"]
}

moved {
  from = hcloud_zone_rrset.fastmail_dkim3["pling.org.uk"]
  to   = module.fastmail["pling.org.uk"].hcloud_zone_rrset.dkim["fm3"]
}
