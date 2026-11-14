module "chrisn_xyz_namespace" {
  source = "../../tfmodules/app-namespace"

  name = "chrisn-xyz"
}

module "chrisn_xyz_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/chrisn.xyz"
  role_name     = "chrisn-xyz"
  k8s_namespace = module.chrisn_xyz_namespace.name
}

module "chrisn_xyz_wordpress_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "chrisn-xyz/wordpress"
  k8s_secret_name          = "wordpress"
  k8s_namespace            = module.chrisn_xyz_namespace.name
  k8s_service_account_name = "chrisn-xyz-wordpress-secrets"
  vault_role_name          = "chrisn-xyz-wordpress-secrets"
}

module "chrisn_xyz_gcp_backups_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "backups/service-account-creds"
  k8s_secret_name          = "gcp-backups"
  k8s_namespace            = module.chrisn_xyz_namespace.name
  k8s_service_account_name = "chrisn-xyz-gcp-backups"
  vault_role_name          = "chrisn-xyz-gcp-backups"
}
