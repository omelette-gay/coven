# Chris's old domain: mail still goes to Fastmail, and the website redirects to chrisn.xyz

resource "hcloud_zone" "cjn_me_uk" {
  name = "cjn.me.uk"
  mode = "primary"
}

module "cjn_me_uk_fastmail" {
  source = "../../tfmodules/fastmail"

  zone = hcloud_zone.cjn_me_uk
}

module "cjn_me_uk_decommissioned" {
  source = "../../tfmodules/decommissioned-domain"

  name            = "cjn-me-uk"
  hostnames       = ["cjn.me.uk", "www.cjn.me.uk"]
  redirect_target = "https://chrisn.xyz/"
}
