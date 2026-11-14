# verify omelette.gay for the omelette-gay GitHub organisation

module "github_domain_verification" {
  source = "../../tfmodules/github-domain-verification"

  zone              = data.hcloud_zone.omelette_gay
  organisation      = "omelette-gay"
  verification_code = "003bfe87d7"
}
