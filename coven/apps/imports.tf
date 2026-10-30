# Resources moved out of the coven/ root module (ADR 002). Delete this file once it's been applied.
#
# Minecraft's RCON password isn't imported, as its import ID is the password itself. It's regenerated instead.

locals {
  # zone IDs, as the records' zone attribute is the ID, and importing by name would force them to be replaced
  imported_fastmail_zones = {
    "animebots.co.uk"          = "819527"
    "barcampmanchester.co.uk"  = "819524"
    "chrisn.xyz"               = "819528"
    "cjn.me.uk"                = "819531"
    "dxhosting.co.uk"          = "819529"
    "manchestertechnights.org" = "819530"
    "pling.org.uk"             = "819525"
  }
}

import {
  to = hcloud_zone.animebots_co_uk
  id = "animebots.co.uk"
}

import {
  to = hcloud_zone.barcampmanchester_co_uk
  id = "barcampmanchester.co.uk"
}

import {
  to = hcloud_zone.chrisn_xyz
  id = "chrisn.xyz"
}

import {
  to = hcloud_zone.cjn_me_uk
  id = "cjn.me.uk"
}

import {
  to = hcloud_zone.dxhosting_co_uk
  id = "dxhosting.co.uk"
}

import {
  to = hcloud_zone.manchestertechnights_org
  id = "manchestertechnights.org"
}

import {
  to = hcloud_zone.moretobooks_com
  id = "moretobooks.com"
}

import {
  to = hcloud_zone.pling_org_uk
  id = "pling.org.uk"
}

import {
  for_each = local.imported_fastmail_zones
  to       = module.fastmail[each.key].hcloud_zone_rrset.mx
  id       = "${each.value}/@/MX"
}

import {
  for_each = local.imported_fastmail_zones
  to       = module.fastmail[each.key].hcloud_zone_rrset.spf
  id       = "${each.value}/@/TXT"
}

import {
  for_each = local.imported_fastmail_zones
  to       = module.fastmail[each.key].hcloud_zone_rrset.dmarc
  id       = "${each.value}/_dmarc/TXT"
}

import {
  for_each = {
    for pair in setproduct(keys(local.imported_fastmail_zones), ["fm1", "fm2", "fm3"]) : "${pair[0]}/${pair[1]}" => pair
  }
  to = module.fastmail[each.value[0]].hcloud_zone_rrset.dkim[each.value[1]]
  id = "${local.imported_fastmail_zones[each.value[0]]}/${each.value[1]}._domainkey/CNAME"
}

import {
  to = hcloud_zone_rrset.chris_bsky
  id = "819528/_atproto/TXT"
}

import {
  to = hcloud_zone_rrset.dizzy_bsky
  id = "798597/_atproto.dizzy/TXT"
}

import {
  to = hcloud_zone_rrset.emily_bsky
  id = "798597/_atproto.emily/TXT"
}

import {
  to = module.girlsclub_minecraft.kubernetes_namespace_v1.this
  id = "minecraft-girlsclub"
}

import {
  to = module.girlsclub_minecraft.kubernetes_secret_v1.rcon[0]
  id = "minecraft-girlsclub/girlsclub-rcon"
}

import {
  to = module.girlsclub_minecraft.kubernetes_persistent_volume_claim_v1.backups[0]
  id = "minecraft-girlsclub/girlsclub-minecraft-backupdir"
}

import {
  to = module.girlsclub_minecraft.kubernetes_config_map_v1.prometheus_exporter_config
  id = "minecraft-girlsclub/girlsclub-minecraft-prometheus-config"
}

import {
  to = module.girlsclub_minecraft.kubernetes_manifest.minecraft_pod_monitor
  id = "apiVersion=monitoring.coreos.com/v1,kind=PodMonitor,namespace=minecraft-girlsclub,name=girlsclub-minecraft"
}

import {
  to = module.girlsclub_minecraft.helm_release.minecraft
  id = "minecraft-girlsclub/girlsclub"
}

import {
  to = module.girlsclub_minecraft.hcloud_zone_rrset.srv[0]
  id = "798597/_minecraft._tcp/SRV"
}

import {
  to = module.trivy.kubernetes_namespace_v1.trivy_system
  id = "trivy-system"
}

import {
  to = module.trivy.helm_release.trivy_operator
  id = "trivy-system/trivy-operator"
}
