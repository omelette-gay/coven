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

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.weight_tracker_namespace.kubernetes_namespace_v1.this
  id = "weight-tracker"
}

import {
  to = module.weight_tracker_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-weight-tracker"
}

import {
  to = module.weight_tracker_deployment.vault_policy.this
  id = "github-weight-tracker"
}

import {
  to = module.weight_tracker_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-weight-tracker"
}

import {
  to = module.weight_tracker_google_oauth_secret.kubernetes_service_account_v1.reader
  id = "weight-tracker/weight-tracker-google-oauth-secret"
}

import {
  to = module.weight_tracker_google_oauth_secret.vault_policy.reader
  id = "weight-tracker-secrets"
}

import {
  to = module.weight_tracker_google_oauth_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/weight-tracker-secrets"
}

import {
  to = module.weight_tracker_google_oauth_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=weight-tracker,name=vault-weight-tracker-secrets"
}

import {
  to = module.weight_tracker_google_oauth_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=weight-tracker,name=google-oauth"
}

import {
  to = module.weight_tracker_google_service_account_secret.kubernetes_service_account_v1.reader
  id = "weight-tracker/weight-tracker"
}

import {
  to = module.weight_tracker_google_service_account_secret.vault_policy.reader
  id = "weight-tracker-google-secret"
}

import {
  to = module.weight_tracker_google_service_account_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/weight-tracker-google-secret"
}

import {
  to = module.weight_tracker_google_service_account_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=weight-tracker,name=vault-weight-tracker-google-secret"
}

import {
  to = module.weight_tracker_google_service_account_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=weight-tracker,name=google-service-account"
}
