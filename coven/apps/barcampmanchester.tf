module "barcampmanchester_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "barcampmanchester"
  ghcr_secret_name = "ghcr-credentials"
}

module "barcampmanchester_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/barcampmanchester.co.uk"
  role_name     = "barcampmanchester"
  k8s_namespace = module.barcampmanchester_namespace.name
}
