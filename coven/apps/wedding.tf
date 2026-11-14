module "wedding_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "wedding"
  ghcr_secret_name = "ghcr-credentials"
}

module "wedding_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "omelette-gay/wedding"
  role_name     = "wedding"
  k8s_namespace = module.wedding_namespace.name
}

module "wedding_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "wedding/app"
  k8s_secret_name          = "wedding-app-secrets"
  k8s_namespace            = module.wedding_namespace.name
  k8s_service_account_name = "wedding-app-secrets"
  vault_role_name          = "wedding-app-secrets"
}

module "wedding_gcp_backup_creds_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "backups/service-account-key"
  k8s_secret_name          = "wedding-gcp-backup-creds"
  k8s_namespace            = module.wedding_namespace.name
  k8s_service_account_name = "wedding-gcp-backup-creds"
  vault_role_name          = "wedding-gcp-backup-creds"
}

module "wedding_sso" {
  source = "../../tfmodules/keycloak-client"

  keycloak_url        = "${local.keycloak_url}${local.keycloak_base_path}"
  realm_id            = local.keycloak_realm
  client_id           = "wedding"
  client_name         = "Wedding"
  valid_redirect_uris = ["https://wedding.omelette.gay/oidc/callback/"]
  k8s_namespace       = module.wedding_namespace.name
  k8s_secret_name     = "wedding-sso-secrets"
}

# Adopt the resources that Ansible created. Remove these blocks once applied. The Keycloak IDs are the UUIDs Keycloak
# assigned, which aren't secret. (A data source would look them up, but the client's data source holds its secret, which
# would be stored in state.)
import {
  to = module.wedding_namespace.kubernetes_namespace_v1.this
  id = "wedding"
}

import {
  to = module.wedding_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "wedding/ghcr-creds-reader"
}

import {
  to = module.wedding_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/wedding-ghcr-creds"
}

import {
  to = module.wedding_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=wedding,name=ghcr"
}

import {
  to = module.wedding_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=wedding,name=ghcr-credentials"
}

import {
  to = module.wedding_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-wedding"
}

import {
  to = module.wedding_deployment.vault_policy.this
  id = "github-wedding"
}

import {
  to = module.wedding_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-wedding"
}

import {
  to = module.wedding_app_secret.kubernetes_service_account_v1.reader
  id = "wedding/wedding-app-secrets"
}

import {
  to = module.wedding_app_secret.vault_policy.reader
  id = "wedding-app-secrets"
}

import {
  to = module.wedding_app_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/wedding-app-secrets"
}

import {
  to = module.wedding_app_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=wedding,name=vault-wedding-app-secrets"
}

import {
  to = module.wedding_app_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=wedding,name=wedding-app-secrets"
}

import {
  to = module.wedding_gcp_backup_creds_secret.kubernetes_service_account_v1.reader
  id = "wedding/wedding-gcp-backup-creds"
}

import {
  to = module.wedding_gcp_backup_creds_secret.vault_policy.reader
  id = "wedding-gcp-backup-creds"
}

import {
  to = module.wedding_gcp_backup_creds_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/wedding-gcp-backup-creds"
}

import {
  to = module.wedding_gcp_backup_creds_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=wedding,name=vault-wedding-gcp-backup-creds"
}

import {
  to = module.wedding_gcp_backup_creds_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=wedding,name=wedding-gcp-backup-creds"
}

import {
  to = module.wedding_sso.keycloak_openid_client.this
  id = "${local.keycloak_realm}/4920db68-ae4d-47da-aa83-af68ea7e4b73"
}

import {
  to = module.wedding_sso.keycloak_openid_user_client_role_protocol_mapper.roles
  id = "${local.keycloak_realm}/client/4920db68-ae4d-47da-aa83-af68ea7e4b73/6e8fc8f5-3843-4d8e-9ea0-b09a7be400e9"
}

import {
  to = module.wedding_sso.kubernetes_secret_v1.this
  id = "wedding/wedding-sso-secrets"
}
