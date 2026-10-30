# Resources moved out of the coven/ root module (ADR 002). Delete this file once it's been applied.
#
# The backup service account keys (and their rotation timestamps) aren't imported: a service account key can't be
# imported, and an imported HMAC key has no secret. They're created fresh here, which rotates them early, and the old
# ones are destroyed by the coven/ root module.
#
# GlitchTip's write-only secrets are imported without a revision recorded, so the first apply writes them. To stop that
# rotating them, its current values are passed in from Vault (see main.tf), so the same values are written back.

import {
  to = vault_kubernetes_secret_backend_role.gitops_github_action
  id = "kubernetes/roles/github-gitops"
}

import {
  to = vault_policy.github_deployment
  id = "github-gitops"
}

import {
  to = vault_jwt_auth_backend_role.github_deployment
  id = "auth/github/role/github-gitops"
}

import {
  to = vault_kv_secret_v2.backup_service_account_creds
  id = "secret/data/backups/service-account-creds"
}

import {
  to = vault_kv_secret_v2.backup_service_account_key
  id = "secret/data/backups/service-account-key"
}

import {
  to = module.platform.module.glitchtip.kubernetes_namespace_v1.this
  id = "glitchtip"
}

import {
  to = module.platform.module.glitchtip.kubernetes_secret_v1.secret
  id = "glitchtip/glitchtip-secrets"
}

import {
  to = module.platform.module.glitchtip.kubernetes_manifest.block_metrics_path
  id = "apiVersion=traefik.io/v1alpha1,kind=Middleware,namespace=glitchtip,name=block-metrics-path"
}

import {
  to = module.platform.module.glitchtip.kubernetes_manifest.probe
  id = "apiVersion=monitoring.coreos.com/v1,kind=Probe,namespace=glitchtip,name=glitchtip-https"
}

import {
  to = module.platform.module.glitchtip.helm_release.this
  id = "glitchtip/glitchtip"
}

import {
  to = module.platform.module.glitchtip.kubernetes_job_v1.configure_oidc
  id = "glitchtip/glitchtip-configure-oidc"
}

import {
  to = module.platform.module.glitchtip.module.keycloak_client.keycloak_openid_client.this
  id = "omelette.gay/03066253-9fba-4b57-a091-0c74eacc2b7f"
}

import {
  to = module.platform.module.glitchtip.module.keycloak_client.keycloak_openid_user_client_role_protocol_mapper.roles
  id = "omelette.gay/client/03066253-9fba-4b57-a091-0c74eacc2b7f/8f7e97fa-8a50-4327-839b-ae94781aa861"
}

import {
  to = module.platform.module.glitchtip.module.keycloak_client.kubernetes_secret_v1.this
  id = "glitchtip/glitchtip-oidc"
}

import {
  to = module.platform.module.glitchtip.module.object_store.kubernetes_secret_v1.credentials
  id = "glitchtip/glitchtip-object-store-credentials"
}

import {
  to = module.platform.module.glitchtip.module.object_store.helm_release.this
  id = "glitchtip/glitchtip-rustfs"
}

import {
  to = module.platform.module.glitchtip.module.object_store.kubernetes_job_v1.bucket["glitchtip"]
  id = "glitchtip/create-glitchtip-bucket-glitchtip"
}
