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

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.chrisn_xyz_namespace.kubernetes_namespace_v1.this
  id = "chrisn-xyz"
}

import {
  to = module.chrisn_xyz_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-chrisn-xyz"
}

import {
  to = module.chrisn_xyz_deployment.vault_policy.this
  id = "github-chrisn-xyz"
}

import {
  to = module.chrisn_xyz_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-chrisn-xyz"
}

import {
  to = module.chrisn_xyz_wordpress_secret.kubernetes_service_account_v1.reader
  id = "chrisn-xyz/chrisn-xyz-wordpress-secrets"
}

import {
  to = module.chrisn_xyz_wordpress_secret.vault_policy.reader
  id = "chrisn-xyz-wordpress-secrets"
}

import {
  to = module.chrisn_xyz_wordpress_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/chrisn-xyz-wordpress-secrets"
}

import {
  to = module.chrisn_xyz_wordpress_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=chrisn-xyz,name=vault-chrisn-xyz-wordpress-secrets"
}

import {
  to = module.chrisn_xyz_wordpress_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=chrisn-xyz,name=wordpress"
}

import {
  to = module.chrisn_xyz_gcp_backups_secret.kubernetes_service_account_v1.reader
  id = "chrisn-xyz/chrisn-xyz-gcp-backups"
}

import {
  to = module.chrisn_xyz_gcp_backups_secret.vault_policy.reader
  id = "chrisn-xyz-gcp-backups"
}

import {
  to = module.chrisn_xyz_gcp_backups_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/chrisn-xyz-gcp-backups"
}

import {
  to = module.chrisn_xyz_gcp_backups_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=chrisn-xyz,name=vault-chrisn-xyz-gcp-backups"
}

import {
  to = module.chrisn_xyz_gcp_backups_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=chrisn-xyz,name=gcp-backups"
}
