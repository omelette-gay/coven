module "wedding_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "wedding"
  ghcr_secret_name = "ghcr-credentials"
}

module "wedding_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "omelette-gay/wedding"
  role_name     = "wedding"
  k8s_namespace = module.wedding_namespace.name
}

module "wedding_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "wedding/app"
  k8s_secret_name          = "wedding-app-secrets"
  k8s_namespace            = module.wedding_namespace.name
  k8s_service_account_name = "wedding-app-secrets"
  vault_role_name          = "wedding-app-secrets"
}

module "wedding_gcp_backup_creds_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "backups/service-account-key"
  k8s_secret_name          = "wedding-gcp-backup-creds"
  k8s_namespace            = module.wedding_namespace.name
  k8s_service_account_name = "wedding-gcp-backup-creds"
  vault_role_name          = "wedding-gcp-backup-creds"
}

module "wedding_sso" {
  source = "../../tfmodules/keycloak-client"

  keycloak_url        = "${local.keycloak_url}${local.keycloak_base_path}"
  realm_id            = local.keycloak_realm
  client_id           = "wedding"
  client_name         = "Wedding"
  valid_redirect_uris = ["https://wedding.omelette.gay/oidc/callback/"]
  k8s_namespace       = module.wedding_namespace.name
  k8s_secret_name     = "wedding-sso-secrets"
}
