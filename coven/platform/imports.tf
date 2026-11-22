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
