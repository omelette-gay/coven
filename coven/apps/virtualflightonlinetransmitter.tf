module "virtualflightonlinetransmitter_namespace" {
  source = "../../tfmodules/app-namespace"

  name = "virtualflightonlinetransmitter"
}

module "virtualflightonlinetransmitter_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/virtualflightonlinetransmitter"
  role_name     = "virtualflightonlinetransmitter"
  k8s_namespace = module.virtualflightonlinetransmitter_namespace.name
}

module "virtualflightonlinetransmitter_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "virtualflightonlinetransmitter/app"
  k8s_secret_name          = "server-secret"
  k8s_namespace            = module.virtualflightonlinetransmitter_namespace.name
  k8s_service_account_name = "virtualflightonlinetransmitter-secrets"
  vault_role_name          = "virtualflightonlinetransmitter-secrets"
}
