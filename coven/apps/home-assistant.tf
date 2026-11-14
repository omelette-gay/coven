module "home_assistant_namespace" {
  source = "../../tfmodules/app-namespace"

  name             = "home-assistant"
  ghcr_secret_name = "ghcr-credentials"
}

module "home_assistant_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "omelette-gay/home-assistant"
  role_name     = "home-assistant"
  k8s_namespace = module.home_assistant_namespace.name
}

module "home_assistant_sso" {
  source = "../../tfmodules/keycloak-client"

  keycloak_url        = "${local.keycloak_url}${local.keycloak_base_path}"
  realm_id            = local.keycloak_realm
  client_id           = "home-assistant"
  client_name         = "Home Assistant"
  valid_redirect_uris = ["https://home.gs.omelette.gay/auth/oidc/callback"]
  client_roles        = ["admin", "resident"]
  role_groups = {
    admin = ["admins"]
  }
  k8s_namespace   = module.home_assistant_namespace.name
  k8s_secret_name = "home-assistant-sso-secrets"
}

# Adopt the resources that Ansible created. Remove these blocks once applied. The Keycloak IDs are the UUIDs Keycloak
# assigned, which aren't secret. (A data source would look them up, but the client's data source holds its secret, which
# would be stored in state.)
import {
  to = module.home_assistant_namespace.kubernetes_namespace_v1.this
  id = "home-assistant"
}

import {
  to = module.home_assistant_namespace.kubernetes_service_account_v1.ghcr_reader[0]
  id = "home-assistant/ghcr-creds-reader"
}

import {
  to = module.home_assistant_namespace.vault_kubernetes_auth_backend_role.ghcr_reader[0]
  id = "auth/kubernetes/role/home-assistant-ghcr-creds"
}

import {
  to = module.home_assistant_namespace.kubernetes_manifest.ghcr_secret_store[0]
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=home-assistant,name=ghcr"
}

import {
  to = module.home_assistant_namespace.kubernetes_manifest.ghcr_credentials[0]
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=home-assistant,name=ghcr-credentials"
}

import {
  to = module.home_assistant_deployment.vault_kubernetes_secret_backend_role.this
  id = "kubernetes/roles/github-home-assistant"
}

import {
  to = module.home_assistant_deployment.vault_policy.this
  id = "github-home-assistant"
}

import {
  to = module.home_assistant_deployment.vault_jwt_auth_backend_role.this
  id = "auth/github/role/github-home-assistant"
}

import {
  to = module.home_assistant_sso.keycloak_openid_client.this
  id = "${local.keycloak_realm}/2368fd56-625d-461f-9e94-724409f63c58"
}

import {
  to = module.home_assistant_sso.keycloak_openid_user_client_role_protocol_mapper.roles
  id = "${local.keycloak_realm}/client/2368fd56-625d-461f-9e94-724409f63c58/fc0af6cd-1253-4838-8d2b-5da80c07eea7"
}

import {
  to = module.home_assistant_sso.kubernetes_secret_v1.this
  id = "home-assistant/home-assistant-sso-secrets"
}

import {
  to = module.home_assistant_sso.keycloak_role.this["admin"]
  id = "${local.keycloak_realm}/13458dff-542f-48e7-8104-d9761e4596dd"
}

import {
  to = module.home_assistant_sso.keycloak_role.this["resident"]
  id = "${local.keycloak_realm}/d8b19331-0064-4572-9fab-1a89c528f880"
}
