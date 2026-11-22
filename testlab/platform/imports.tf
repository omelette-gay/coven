# Imports what Ansible made into the platform stack (#561). Remove these blocks once they've been applied.

import {
  to = module.platform.keycloak_realm.omelette_gay
  id = "omelette.gay"
}

import {
  to = module.platform.keycloak_group.admins
  id = "omelette.gay/6f892ff3-e451-48bd-b62a-b5abd0954066"
}

import {
  to = module.platform.keycloak_user.automation
  id = "master/12e178fb-3c2b-400d-8b02-14b18964dc99"
}

import {
  to = module.platform.keycloak_user_roles.automation
  id = "master/12e178fb-3c2b-400d-8b02-14b18964dc99"
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
