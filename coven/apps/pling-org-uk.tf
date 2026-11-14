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

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.pling_org_uk_namespace.kubernetes_namespace_v1.this
  id = "pling-org-uk"
}

import {
  to = module.pling_org_uk_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "pling-org-uk/ghcr-creds-reader"
}

import {
  to = module.pling_org_uk_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/pling-org-uk-ghcr-creds"
}

import {
  to = module.pling_org_uk_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=pling-org-uk,name=ghcr"
}

import {
  to = module.pling_org_uk_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=pling-org-uk,name=ghcr-credentials"
}

import {
  to = module.pling_org_uk_www_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-www-pling-org-uk"
}

import {
  to = module.pling_org_uk_www_deployment.vault_policy.this
  id = "github-www-pling-org-uk"
}

import {
  to = module.pling_org_uk_www_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-www-pling-org-uk"
}

import {
  to = module.whereisthenorthreally_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-whereisthenorthreally"
}

import {
  to = module.whereisthenorthreally_deployment.vault_policy.this
  id = "github-whereisthenorthreally"
}

import {
  to = module.whereisthenorthreally_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-whereisthenorthreally"
}

import {
  to = module.what_if_proportional_representation_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-what-if-proportional-representation"
}

import {
  to = module.what_if_proportional_representation_deployment.vault_policy.this
  id = "github-what-if-proportional-representation"
}

import {
  to = module.what_if_proportional_representation_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-what-if-proportional-representation"
}

import {
  to = module.ubi_calculator_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-ubi-calculator"
}

import {
  to = module.ubi_calculator_deployment.vault_policy.this
  id = "github-ubi-calculator"
}

import {
  to = module.ubi_calculator_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-ubi-calculator"
}

import {
  to = module.whereisthenorthreally_gcp_backups_secret.kubernetes_service_account_v1.reader
  id = "pling-org-uk/whereisthenorthreally-gcp-backups"
}

import {
  to = module.whereisthenorthreally_gcp_backups_secret.vault_policy.reader
  id = "whereisthenorthreally-gcp-backups"
}

import {
  to = module.whereisthenorthreally_gcp_backups_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/whereisthenorthreally-gcp-backups"
}

import {
  to = module.whereisthenorthreally_gcp_backups_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=pling-org-uk,name=vault-whereisthenorthreally-gcp-backups"
}

import {
  to = module.whereisthenorthreally_gcp_backups_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=pling-org-uk,name=whereisthenorthreally-gcp-backups"
}
