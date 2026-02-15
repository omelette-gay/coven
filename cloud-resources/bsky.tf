# verify some custom domains for Bluesky

resource "hcloud_zone_rrset" "chris_bsky" {
  name = "_atproto"
  type = "TXT"
  zone = hcloud_zone.chrisn_xyz.id
  records = [
    { value = provider::hcloud::txt_record("did=did:plc:cp5bwqddwws4ylsfjmbbcv5t") }
  ]
}

resource "hcloud_zone_rrset" "dizzy_bsky" {
  name = "_atproto.dizzy"
  type = "TXT"
  zone = hcloud_zone.omelette_gay.id
  records = [
    { value = provider::hcloud::txt_record("did=did:plc:mzojqfcqta5qv3mqunoxojcg") }
  ]
}

resource "hcloud_zone_rrset" "emily_bsky" {
  name = "_atproto.emily"
  type = "TXT"
  zone = hcloud_zone.omelette_gay.id
  records = [
    { value = provider::hcloud::txt_record("did=did:plc:jeobzen65n6ugbzawbvrunxu") }
  ]
}
