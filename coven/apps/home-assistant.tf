module "home_assistant_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "home-assistant"
  ghcr_secret_name = "ghcr-credentials"
}

module "home_assistant_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "omelette-gay/home-assistant"
  role_name     = "home-assistant"
  k8s_namespace = module.home_assistant_namespace.name
}

module "home_assistant_sso" {
  source = "../../tfmodules/keycloak-client"

  keycloak_url        = "${local.keycloak_url}${local.keycloak_base_path}"
  keycloak_realm      = local.keycloak_realm
  client_id           = "home-assistant"
  client_name         = "Home Assistant"
  valid_redirect_uris = ["https://home.gs.omelette.gay/auth/oidc/callback"]
  client_roles        = ["admin", "resident"]
  k8s_namespace       = module.home_assistant_namespace.name
  k8s_secret_name     = "home-assistant-sso-secrets"
}

# The admin role's grant used to be made by the keycloak-client module, and is now in sso-groups.tf. Forget it rather
# than destroying it, which would take the role away from admins.
removed {
  from = module.home_assistant_sso.keycloak_group_roles.this

  lifecycle {
    destroy = false
  }
}
