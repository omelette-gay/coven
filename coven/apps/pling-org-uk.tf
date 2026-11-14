module "pling_org_uk_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "pling-org-uk"
  ghcr_secret_name = "ghcr-credentials"
}

module "pling_org_uk_www_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/www.pling.org.uk"
  role_name     = "www-pling-org-uk"
  k8s_namespace = module.pling_org_uk_namespace.name
}

module "whereisthenorthreally_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/whereisthenorthreally"
  role_name     = "whereisthenorthreally"
  k8s_namespace = module.pling_org_uk_namespace.name
}

module "what_if_proportional_representation_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/what-if-proportional-representation"
  role_name     = "what-if-proportional-representation"
  k8s_namespace = module.pling_org_uk_namespace.name
}

module "ubi_calculator_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/ubi-calculator"
  role_name     = "ubi-calculator"
  k8s_namespace = module.pling_org_uk_namespace.name
}

module "whereisthenorthreally_gcp_backups_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "backups/service-account-creds"
  k8s_secret_name          = "whereisthenorthreally-gcp-backups"
  k8s_namespace            = module.pling_org_uk_namespace.name
  k8s_service_account_name = "whereisthenorthreally-gcp-backups"
  vault_role_name          = "whereisthenorthreally-gcp-backups"
}
