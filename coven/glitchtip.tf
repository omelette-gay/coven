module "glitchtip" {
  source = "../tfmodules/glitchtip"

  domain               = "errors.omelette.gay"
  keycloak_url         = "${local.keycloak_url}${local.keycloak_base_path}"
  postgresql_instances = 2
}
