# verify omelette.gay (and so its subdomains) for the omelette-gay GitHub organisation, from the organisation's
# Settings → Verified and approved domains

resource "hcloud_zone_rrset" "github_org_verification" {
  name = "_gh-omelette-gay-o"
  type = "TXT"
  zone = data.hcloud_zone.omelette_gay.id
  records = [
    { value = provider::hcloud::txt_record("003bfe87d7") }
  ]
}
