module "manchestertechnights_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "manchestertechnights"
  ghcr_secret_name = "ghcr-credentials"
}

module "manchestertechnights_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/manchestertechnights.org"
  role_name     = "manchestertechnights"
  k8s_namespace = module.manchestertechnights_namespace.name
}

module "manchestertechnights_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "manchestertechnights/app"
  k8s_secret_name          = "app-secret"
  k8s_namespace            = module.manchestertechnights_namespace.name
  k8s_service_account_name = "manchestertechnights-secrets"
  vault_role_name          = "manchestertechnights-secrets"
}
