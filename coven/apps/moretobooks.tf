module "moretobooks_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "moretobooks"
  ghcr_secret_name = "ghcr-credentials"
}

module "moretobooks_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/moretobooks"
  role_name     = "moretobooks"
  k8s_namespace = module.moretobooks_namespace.name
}
