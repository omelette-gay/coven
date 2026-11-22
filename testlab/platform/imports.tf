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
  id = "omelette.gay/a4e38c12-d666-4ada-9fcc-8481cabcf255"
}

import {
  to = module.platform.keycloak_openid_user_client_role_protocol_mapper.vault_roles
  id = "omelette.gay/client/a4e38c12-d666-4ada-9fcc-8481cabcf255/48a0a6db-5e50-4450-b43f-463757c39fdc"
}

import {
  to = module.platform.keycloak_role.vault_admin
  id = "omelette.gay/449a48a2-ea14-40f5-aa6b-0fed42cf4949"
}

import {
  to = module.platform.keycloak_group_roles.admins_vault
  id = "omelette.gay/6f892ff3-e451-48bd-b62a-b5abd0954066"
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

import {
  to = module.platform.module.grafana_sso.keycloak_openid_client.this
  id = "omelette.gay/de46434b-1457-480b-a023-54cc0fc1c6c4"
}

import {
  to = module.platform.module.grafana_sso.keycloak_openid_user_client_role_protocol_mapper.roles
  id = "omelette.gay/client/de46434b-1457-480b-a023-54cc0fc1c6c4/75401926-95a5-409a-b483-670226f0dab3"
}

import {
  to = module.platform.module.grafana_sso.keycloak_role.this["grafana-admin"]
  id = "omelette.gay/4831f0f1-ccb1-4882-a526-305e56648c63"
}

import {
  to = module.platform.module.grafana_sso.keycloak_group_roles.this["admins"]
  id = "omelette.gay/6f892ff3-e451-48bd-b62a-b5abd0954066"
}

import {
  to = module.platform.module.grafana_sso.kubernetes_secret_v1.this
  id = "monitoring/grafana-keycloak-creds"
}

import {
  to = module.platform.kubernetes_manifest.grafana_probe
  id = "apiVersion=monitoring.coreos.com/v1,kind=Probe,namespace=monitoring,name=grafana-https"
}

import {
  to = module.platform.module.loki_object_store.helm_release.this
  id = "monitoring/loki-rustfs"
}

import {
  to = module.platform.module.loki_object_store.kubernetes_job_v1.bucket["loki-chunks"]
  id = "monitoring/create-loki-bucket-loki-chunks"
}

import {
  to = module.platform.module.loki_object_store.kubernetes_job_v1.bucket["loki-ruler"]
  id = "monitoring/create-loki-bucket-loki-ruler"
}

import {
  to = module.platform.module.loki_object_store.kubernetes_job_v1.bucket["loki-admin"]
  id = "monitoring/create-loki-bucket-loki-admin"
}

import {
  to = module.platform.helm_release.loki
  id = "monitoring/loki"
}

import {
  to = module.platform.kubernetes_config_map_v1.loki_data_source
  id = "monitoring/loki-data-source"
}

import {
  to = module.platform.helm_release.alloy
  id = "monitoring/alloy"
}

import {
  to = module.platform.module.longhorn_backup_credentials.kubernetes_service_account_v1.reader
  id = "longhorn-system/longhorn-gcp-backup-creds"
}

import {
  to = module.platform.module.longhorn_backup_credentials.vault_policy.reader
  id = "longhorn-gcp-backup-creds"
}

import {
  to = module.platform.module.longhorn_backup_credentials.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/longhorn-gcp-backup-creds"
}

import {
  to = module.platform.module.longhorn_backup_credentials.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=longhorn-system,name=vault-longhorn-gcp-backup-creds"
}

import {
  to = module.platform.module.longhorn_backup_credentials.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=longhorn-system,name=gcp-backup-creds"
}

import {
  to = module.platform.kubernetes_manifest.longhorn_backup_job
  id = "apiVersion=longhorn.io/v1beta2,kind=RecurringJob,namespace=longhorn-system,name=nightly-backup"
}

import {
  to = module.platform.kubernetes_manifest.longhorn_snapshot_job
  id = "apiVersion=longhorn.io/v1beta2,kind=RecurringJob,namespace=longhorn-system,name=daily-snapshot"
}

import {
  to = module.platform.kubernetes_namespace_v1.mail
  id = "mail"
}

import {
  to = module.platform.module.dkim_key.kubernetes_service_account_v1.reader
  id = "mail/outbound-mail-dkim"
}

import {
  to = module.platform.module.dkim_key.vault_policy.reader
  id = "outbound-mail-dkim"
}

import {
  to = module.platform.module.dkim_key.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/outbound-mail-dkim"
}

import {
  to = module.platform.module.dkim_key.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=mail,name=vault-outbound-mail-dkim"
}

import {
  to = module.platform.module.dkim_key.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=mail,name=dkim"
}

import {
  to = module.platform.helm_release.mail
  id = "mail/mail"
}

import {
  to = module.platform.kubernetes_namespace_v1.mariadb
  id = "mariadb-system"
}

import {
  to = module.platform.helm_release.mariadb_operator_crds
  id = "mariadb-system/mariadb-operator-crds"
}

import {
  to = module.platform.helm_release.mariadb_operator
  id = "mariadb-system/mariadb-operator"
}
