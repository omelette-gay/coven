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

import {
  to = module.platform.module.grafana_sso.keycloak_openid_client.this
  id = "omelette.gay/65155a71-5c19-454c-b501-01789254cfa9"
}

import {
  to = module.platform.module.grafana_sso.keycloak_openid_user_client_role_protocol_mapper.roles
  id = "omelette.gay/client/65155a71-5c19-454c-b501-01789254cfa9/9174f0d8-073b-4fd4-acbd-c5c30ed57936"
}

import {
  to = module.platform.module.grafana_sso.keycloak_role.this["grafana-admin"]
  id = "omelette.gay/f160357a-b286-4079-8ce7-b249abaafe12"
}

import {
  to = module.platform.module.grafana_sso.keycloak_group_roles.this["admins"]
  id = "omelette.gay/9347e574-b522-462d-9b0d-1d0a5d28a0bd"
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
  to = module.platform.kubernetes_manifest.alertmanager_discord[0]
  id = "apiVersion=monitoring.coreos.com/v1alpha1,kind=AlertmanagerConfig,namespace=monitoring,name=alertmanager-discord-notifier"
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
  to = module.platform.kubernetes_namespace_v1.external_dns[0]
  id = "external-dns"
}

import {
  to = module.platform.module.external_dns_hetzner_token[0].kubernetes_service_account_v1.reader
  id = "external-dns/hetzner-secret-reader"
}

import {
  to = module.platform.module.external_dns_hetzner_token[0].vault_policy.reader
  id = "hetzner-hetzner"
}

import {
  to = module.platform.module.external_dns_hetzner_token[0].vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/hetzner-hetzner"
}

import {
  to = module.platform.module.external_dns_hetzner_token[0].kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=external-dns,name=vault-hetzner-hetzner"
}

import {
  to = module.platform.module.external_dns_hetzner_token[0].kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=external-dns,name=hetzner"
}

import {
  to = module.platform.helm_release.external_dns[0]
  id = "external-dns/hetzner"
}

import {
  to = module.platform.hcloud_zone_rrset.extra["strix_a"]
  id = "798597/strix.xdc/A"
}

import {
  to = module.platform.hcloud_zone_rrset.extra["strix_aaaa"]
  id = "798597/strix.xdc/AAAA"
}

import {
  to = module.platform.hcloud_zone_rrset.extra["janus_a"]
  id = "798597/janus.gs/A"
}

import {
  to = module.platform.hcloud_zone_rrset.extra["janus_aaaa"]
  id = "798597/janus.gs/AAAA"
}

import {
  to = module.platform.hcloud_zone_rrset.extra["grimhilde_a"]
  id = "798597/grimhilde.gs/A"
}

import {
  to = module.platform.hcloud_zone_rrset.dkim[0]
  id = "798597/mail._domainkey.coven/TXT"
}

import {
  to = module.platform.hcloud_zone_rrset.spf[0]
  id = "798597/coven/TXT"
}

import {
  to = module.platform.hcloud_zone_rrset.dmarc[0]
  id = "798597/_dmarc.coven/TXT"
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
