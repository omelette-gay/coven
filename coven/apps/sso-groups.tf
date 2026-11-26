# Keycloak groups in the omelette.gay realm, and every role each group holds (see docs/sso.md). Each group's roles are
# exhaustive, so a role granted to the group in the Keycloak UI is removed on the next apply. Who's in each group is
# managed in the Keycloak UI, not here.
#
# To add a group, add a keycloak_group and a keycloak_group_roles with exhaustive = true here. Grant an app's roles with
# its keycloak-client module's role_ids output.

# The admins group, and the Vault and Grafana clients, are made by the platform stack. The platform stack also grants
# vault-admin and grafana-admin to admins, so Vault works on a fresh cluster before this stack is applied.
data "keycloak_group" "admins" {
  realm_id = local.keycloak_realm
  name     = "admins"
}

data "keycloak_openid_client" "platform" {
  for_each = toset(["vault", "grafana"])

  realm_id  = local.keycloak_realm
  client_id = each.key
}

data "keycloak_role" "vault_admin" {
  realm_id  = local.keycloak_realm
  client_id = data.keycloak_openid_client.platform["vault"].id
  name      = "vault-admin"
}

data "keycloak_role" "grafana_admin" {
  realm_id  = local.keycloak_realm
  client_id = data.keycloak_openid_client.platform["grafana"].id
  name      = "grafana-admin"
}

# Chris and Meg. Treat membership as full control of everything
resource "keycloak_group_roles" "admins" {
  realm_id = local.keycloak_realm
  group_id = data.keycloak_group.admins.id
  role_ids = [
    data.keycloak_role.vault_admin.id,
    data.keycloak_role.grafana_admin.id,
    module.home_assistant_sso.role_ids["admin"],
  ]
  exhaustive = true
}
