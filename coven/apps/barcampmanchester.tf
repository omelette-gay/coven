module "barcampmanchester_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "barcampmanchester"
  ghcr_secret_name = "ghcr-credentials"
}

module "barcampmanchester_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/barcampmanchester.co.uk"
  role_name     = "barcampmanchester"
  k8s_namespace = module.barcampmanchester_namespace.name
}

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.barcampmanchester_namespace.kubernetes_namespace_v1.this
  id = "barcampmanchester"
}

import {
  to = module.barcampmanchester_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "barcampmanchester/ghcr-creds-reader"
}

import {
  to = module.barcampmanchester_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/barcampmanchester-ghcr-creds"
}

import {
  to = module.barcampmanchester_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=barcampmanchester,name=ghcr"
}

import {
  to = module.barcampmanchester_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=barcampmanchester,name=ghcr-credentials"
}

import {
  to = module.barcampmanchester_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-barcampmanchester"
}

import {
  to = module.barcampmanchester_deployment.vault_policy.this
  id = "github-barcampmanchester"
}

import {
  to = module.barcampmanchester_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-barcampmanchester"
}
