# Imports what Ansible made into the platform stack (#561). Remove these blocks once they've been applied.

import {
  to = module.platform.keycloak_realm.omelette_gay
  id = "omelette.gay"
}

import {
  to = module.platform.keycloak_group.admins
  id = "omelette.gay/9347e574-b522-462d-9b0d-1d0a5d28a0bd"
}

import {
  to = module.platform.keycloak_user.automation
  id = "master/7ad915d9-6644-4172-a585-3ce97a5f293f"
}

import {
  to = module.platform.keycloak_user_roles.automation
  id = "master/7ad915d9-6644-4172-a585-3ce97a5f293f"
}

import {
  to = module.platform.module.keycloak_backup_credentials.kubernetes_service_account_v1.reader
  id = "keycloak/keycloak-gcp-backup-creds"
}

import {
  to = module.platform.module.keycloak_backup_credentials.vault_policy.reader
  id = "keycloak-gcp-backup-creds"
}

import {
  to = module.platform.module.keycloak_backup_credentials.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/keycloak-gcp-backup-creds"
}

import {
  to = module.platform.module.keycloak_backup_credentials.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=keycloak,name=vault-keycloak-gcp-backup-creds"
}

import {
  to = module.platform.module.keycloak_backup_credentials.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=keycloak,name=keycloak-gcp-backup-creds"
}

import {
  to = module.platform.kubernetes_manifest.keycloak_probe
  id = "apiVersion=monitoring.coreos.com/v1,kind=Probe,namespace=keycloak,name=keycloak-https"
}

import {
  to = module.platform.vault_mount.secret
  id = "secret"
}

import {
  to = module.platform.vault_policy.admin
  id = "admin"
}

import {
  to = module.platform.vault_policy.ghcr_creds_read
  id = "ghcr-creds-read"
}

import {
  to = module.platform.vault_auth_backend.kubernetes
  id = "kubernetes"
}

import {
  to = module.platform.vault_kubernetes_auth_backend_config.kubernetes
  id = "auth/kubernetes/config"
}

import {
  to = module.platform.kubernetes_cluster_role_v1.vault_credential_issuing
  id = "allow-vault-credential-issuing"
}

import {
  to = module.platform.kubernetes_cluster_role_binding_v1.vault_credential_issuing
  id = "allow-vault-credential-issuing"
}

import {
  to = module.platform.vault_kubernetes_secret_backend.kubernetes
  id = "kubernetes"
}

import {
  to = module.platform.vault_kubernetes_secret_backend_role.admin
  id = "kubernetes/roles/admin"
}

import {
  to = module.platform.vault_jwt_auth_backend.github
  id = "github"
}

import {
  to = module.platform.vault_jwt_auth_backend_role.gitops
  id = "auth/github/role/gitops"
}

import {
  to = module.platform.keycloak_openid_client.vault
  id = "omelette.gay/09a9b38d-49b6-403e-8479-947077840331"
}

import {
  to = module.platform.keycloak_openid_user_client_role_protocol_mapper.vault_roles
  id = "omelette.gay/client/09a9b38d-49b6-403e-8479-947077840331/9e67bf2d-5136-4175-a887-82457dd78c5f"
}

import {
  to = module.platform.keycloak_role.vault_admin
  id = "omelette.gay/698ab691-3111-492d-8f71-dfd1a7de6dd3"
}

import {
  to = module.platform.keycloak_group_roles.admins_vault
  id = "omelette.gay/9347e574-b522-462d-9b0d-1d0a5d28a0bd"
}

import {
  to = module.platform.vault_jwt_auth_backend.keycloak
  id = "keycloak"
}

import {
  to = module.platform.vault_jwt_auth_backend_role.keycloak_admin
  id = "auth/keycloak/role/admin"
}

import {
  to = module.platform.kubernetes_manifest.vault_probe
  id = "apiVersion=monitoring.coreos.com/v1,kind=Probe,namespace=vault,name=vault-https"
}

import {
  to = module.platform.vault_mount.pki
  id = "pki"
}

import {
  to = module.platform.vault_pki_secret_backend_role.coven
  id = "pki/roles/coven"
}

import {
  to = module.platform.vault_policy.pki_issuer
  id = "pki-coven-issuer"
}

import {
  to = module.platform.vault_kubernetes_auth_backend_role.cert_manager
  id = "auth/kubernetes/role/cert-manager"
}

import {
  to = module.platform.kubernetes_service_account_v1.vault_issuer
  id = "cert-manager/vault-issuer"
}

import {
  to = module.platform.kubernetes_role_v1.vault_issuer
  id = "cert-manager/vault-issuer"
}

import {
  to = module.platform.kubernetes_role_binding_v1.vault_issuer
  id = "cert-manager/vault-issuer"
}

import {
  to = module.platform.kubernetes_manifest.vault_cluster_issuer
  id = "apiVersion=cert-manager.io/v1,kind=ClusterIssuer,name=vault"
}
