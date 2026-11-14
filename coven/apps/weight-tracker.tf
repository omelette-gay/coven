module "weight_tracker_namespace" {
  source = "../../tfmodules/app-namespace"

  name = "weight-tracker"
}

module "weight_tracker_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/chriss-weight-tracker"
  role_name     = "weight-tracker"
  k8s_namespace = module.weight_tracker_namespace.name
}

module "weight_tracker_google_oauth_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "weight-tracker/google-oauth"
  k8s_secret_name          = "google-oauth"
  k8s_namespace            = module.weight_tracker_namespace.name
  k8s_service_account_name = "weight-tracker-google-oauth-secret"
  vault_role_name          = "weight-tracker-secrets"
}

module "weight_tracker_google_service_account_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "weight-tracker/google-service-account"
  k8s_secret_name          = "google-service-account"
  k8s_namespace            = module.weight_tracker_namespace.name
  k8s_service_account_name = "weight-tracker"
  vault_role_name          = "weight-tracker-google-secret"
}
