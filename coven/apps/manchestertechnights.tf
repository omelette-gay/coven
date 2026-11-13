module "manchestertechnights_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "manchestertechnights"
  ghcr_secret_name = "ghcr-credentials"
}

module "manchestertechnights_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/manchestertechnights.org"
  role_name     = "manchestertechnights"
  k8s_namespace = module.manchestertechnights_namespace.name
}

module "manchestertechnights_app_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "manchestertechnights/app"
  k8s_secret_name          = "app-secret"
  k8s_namespace            = module.manchestertechnights_namespace.name
  k8s_service_account_name = "manchestertechnights-secrets"
  vault_role_name          = "manchestertechnights-secrets"
}

# Adopt the resources that Ansible created. Remove these blocks once applied.
import {
  to = module.manchestertechnights_namespace.kubernetes_namespace_v1.this
  id = "manchestertechnights"
}

import {
  to = module.manchestertechnights_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "manchestertechnights/ghcr-creds-reader"
}

import {
  to = module.manchestertechnights_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/manchestertechnights-ghcr-creds"
}

import {
  to = module.manchestertechnights_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=manchestertechnights,name=ghcr"
}

import {
  to = module.manchestertechnights_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=manchestertechnights,name=ghcr-credentials"
}

import {
  to = module.manchestertechnights_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-manchestertechnights"
}

import {
  to = module.manchestertechnights_deployment.vault_policy.this
  id = "github-manchestertechnights"
}

import {
  to = module.manchestertechnights_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-manchestertechnights"
}

import {
  to = module.manchestertechnights_app_secret.kubernetes_service_account_v1.reader
  id = "manchestertechnights/manchestertechnights-secrets"
}

import {
  to = module.manchestertechnights_app_secret.vault_policy.reader
  id = "manchestertechnights-secrets"
}

import {
  to = module.manchestertechnights_app_secret.vault_kubernetes_auth_backend_role.reader
  id = "auth/kubernetes/role/manchestertechnights-secrets"
}

import {
  to = module.manchestertechnights_app_secret.kubernetes_manifest.secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=manchestertechnights,name=vault-manchestertechnights-secrets"
}

import {
  to = module.manchestertechnights_app_secret.kubernetes_manifest.external_secret[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=manchestertechnights,name=app-secret"
}
