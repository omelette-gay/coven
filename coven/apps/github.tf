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

# verify omelette.gay for GitHub Pages, from the organisation's Settings → Pages. This stops anyone outside the
# organisation using omelette.gay or its subdomains as a custom domain for their own Pages site

resource "hcloud_zone_rrset" "github_pages_verification" {
  name = "_github-pages-challenge-omelette-gay"
  type = "TXT"
  zone = data.hcloud_zone.omelette_gay.id
  records = [
    { value = provider::hcloud::txt_record("890f5de0db0ccbb7c7f2204dce6670") }
  ]
}
