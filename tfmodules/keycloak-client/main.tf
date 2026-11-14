terraform {
  # Write-only arguments (client_secret_wo, data_wo) need 1.11
  required_version = ">= 1.11.0"

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
  client_secret_wo_version = tostring(var.secret_revision)
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

# Grants client roles to groups. The groups must already exist; this module doesn't create or manage them. Each mapping is
# added without touching the group's other roles, as a group holds roles from many clients (exhaustive = false), so a
# role someone adds to the group by hand isn't removed.
locals {
  group_roles = {
    for group in distinct(flatten(values(var.role_groups))) :
    group => [for role, groups in var.role_groups : role if contains(groups, group)]
  }
}

data "keycloak_group" "this" {
  for_each = local.group_roles

  realm_id = var.realm_id
  name     = each.key
}

resource "keycloak_group_roles" "this" {
  for_each = local.group_roles

  realm_id   = var.realm_id
  group_id   = data.keycloak_group.this[each.key].id
  role_ids   = [for role in each.value : keycloak_role.this[role].id]
  exhaustive = false
}

resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = var.k8s_secret_name
    namespace = var.k8s_namespace
  }

  # Write-only, so these values aren't taken from the configuration into state. Everything the app needs is in here, so
  # that every client's Secret has the same keys. Changing secret_revision rewrites all of it, and rotates the client
  # secret (see the variable)
  data_wo = {
    client_id              = var.client_id
    client_secret          = ephemeral.random_password.client_secret.result
    authorization_endpoint = "${var.keycloak_url}/realms/${var.realm_id}/protocol/openid-connect/auth"
    token_endpoint         = "${var.keycloak_url}/realms/${var.realm_id}/protocol/openid-connect/token"
    userinfo_endpoint      = "${var.keycloak_url}/realms/${var.realm_id}/protocol/openid-connect/userinfo"
    jwks_endpoint          = "${var.keycloak_url}/realms/${var.realm_id}/protocol/openid-connect/certs"
  }

  data_wo_revision = var.secret_revision
}
