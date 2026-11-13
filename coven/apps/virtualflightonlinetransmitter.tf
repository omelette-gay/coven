module "virtualflightonlinetransmitter_namespace" {
  source = "../../tfmodules/app-namespace"

  name = "virtualflightonlinetransmitter"
}

module "virtualflightonlinetransmitter_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/virtualflightonlinetransmitter"
  role_name     = "virtualflightonlinetransmitter"
  k8s_namespace = module.virtualflightonlinetransmitter_namespace.name
}

module "virtualflightonlinetransmitter_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "virtualflightonlinetransmitter/app"
  k8s_secret_name          = "server-secret"
  k8s_namespace            = module.virtualflightonlinetransmitter_namespace.name
  k8s_service_account_name = "virtualflightonlinetransmitter-secrets"
  vault_role_name          = "virtualflightonlinetransmitter-secrets"
}

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.virtualflightonlinetransmitter_namespace.kubernetes_namespace_v1.this
  id = "virtualflightonlinetransmitter"
}

import {
  to = module.virtualflightonlinetransmitter_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-virtualflightonlinetransmitter"
}

import {
  to = module.virtualflightonlinetransmitter_deployment.vault_policy.this
  id = "github-virtualflightonlinetransmitter"
}

import {
  to = module.virtualflightonlinetransmitter_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-virtualflightonlinetransmitter"
}

import {
  to = module.virtualflightonlinetransmitter_app_secret.kubernetes_service_account_v1.reader
  id = "virtualflightonlinetransmitter/virtualflightonlinetransmitter-secrets"
}

import {
  to = module.virtualflightonlinetransmitter_app_secret.vault_policy.reader
  id = "virtualflightonlinetransmitter-secrets"
}

import {
  to = module.virtualflightonlinetransmitter_app_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/virtualflightonlinetransmitter-secrets"
}

import {
  to = module.virtualflightonlinetransmitter_app_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=virtualflightonlinetransmitter,name=vault-virtualflightonlinetransmitter-secrets"
}

import {
  to = module.virtualflightonlinetransmitter_app_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=virtualflightonlinetransmitter,name=server-secret"
}
