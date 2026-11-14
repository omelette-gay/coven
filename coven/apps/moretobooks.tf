module "moretobooks_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "moretobooks"
  ghcr_secret_name = "ghcr-credentials"
}

module "moretobooks_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/moretobooks"
  role_name     = "moretobooks"
  k8s_namespace = module.moretobooks_namespace.name
}

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.moretobooks_namespace.kubernetes_namespace_v1.this
  id = "moretobooks"
}

import {
  to = module.moretobooks_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "moretobooks/ghcr-creds-reader"
}

import {
  to = module.moretobooks_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/moretobooks-ghcr-creds"
}

import {
  to = module.moretobooks_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=moretobooks,name=ghcr"
}

import {
  to = module.moretobooks_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=moretobooks,name=ghcr-credentials"
}

import {
  to = module.moretobooks_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-moretobooks"
}

import {
  to = module.moretobooks_deployment.vault_policy.this
  id = "github-moretobooks"
}

import {
  to = module.moretobooks_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-moretobooks"
}
