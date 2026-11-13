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
  realm_id            = local.keycloak_realm
  client_id           = "home-assistant"
  client_name         = "Home Assistant"
  valid_redirect_uris = ["https://home.gs.omelette.gay/auth/oidc/callback"]
  client_roles        = ["admin", "resident"]
  role_groups = {
    admin = ["admins"]
  }
  k8s_namespace   = module.home_assistant_namespace.name
  k8s_secret_name = "home-assistant-sso-secrets"
}
