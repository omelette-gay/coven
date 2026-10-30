# Resources moved out of the coven/ root module (ADR 002). Delete this file once it's been applied.
#
# The backup service account keys (and their rotation timestamps) aren't imported: a service account key can't be
# imported, and an imported HMAC key has no secret. They're created fresh here, which rotates them early, and the old
# ones are destroyed by the coven/ root module.

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
