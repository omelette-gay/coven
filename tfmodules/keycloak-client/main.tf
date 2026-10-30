terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}

ephemeral "random_password" "client_secret" {
  length  = 64
  special = false
}

resource "keycloak_openid_client" "this" {
  realm_id              = var.realm_id
  client_id             = var.client_id
  name                  = var.client_name
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = var.valid_redirect_uris

  client_secret_wo         = ephemeral.random_password.client_secret.result
  client_secret_wo_version = "1"
}

resource "keycloak_openid_user_client_role_protocol_mapper" "roles" {
  realm_id                    = var.realm_id
  client_id                   = keycloak_openid_client.this.id
  name                        = "client roles"
  claim_name                  = "roles"
  multivalued                 = true
  client_id_for_role_mappings = var.client_id
  add_to_id_token             = true
  add_to_access_token         = true
  add_to_userinfo             = true
}

resource "keycloak_role" "this" {
  for_each = toset(var.client_roles)

  realm_id  = var.realm_id
  client_id = keycloak_openid_client.this.id
  name      = each.value
}

resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = var.k8s_secret_name
    namespace = var.k8s_namespace
  }

  data_wo = {
    client_id     = var.client_id
    client_secret = ephemeral.random_password.client_secret.result
  }

  data_wo_revision = 1
}
