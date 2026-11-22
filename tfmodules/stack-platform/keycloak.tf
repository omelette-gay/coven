# The realm everyone logs in to things with. Admin accounts for Keycloak itself are in the master realm. Who can use what
# is up to each app (see docs/sso.md).
resource "keycloak_realm" "omelette_gay" {
  realm       = var.keycloak_realm
  internal_id = "omelette-gay"
  enabled     = true

  user_managed_access         = true
  default_signature_algorithm = "RS256"

  smtp_server {
    from = "keycloak@${var.cluster_domain}"
    host = module.outbound_mail.smtp_host
    port = tostring(module.outbound_mail.smtp_port)
  }
}

# Chris and Meg, who get admin roles in the apps that map them to this group
resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.omelette_gay.id
  name     = "admins"
}

# The user Terraform logs in to Keycloak as, through the credentials in Vault at gitops/keycloak-master-credentials. On a
# fresh cluster, platform's first apply logs in as Keycloak's temporary admin instead (see docs/bootstrapping.md).
#
# Its password is generated when keycloak_automation_password_revision changes, and written to Keycloak and Vault
# together without being stored in state. The provider logs in when the apply starts, so the apply that rotates it carries
# on with its existing session.
ephemeral "random_password" "automation" {
  length  = 64
  special = false
}

resource "keycloak_user" "automation" {
  realm_id = "master"
  username = "ansible-automation"
  enabled  = true

  initial_password {
    value_wo         = ephemeral.random_password.automation.result
    value_wo_version = tostring(var.keycloak_automation_password_revision)
    temporary        = false
  }
}

resource "vault_kv_secret_v2" "keycloak_automation" {
  mount = local.vault.kv_mountpoint
  name  = "gitops/keycloak-master-credentials"

  data_json_wo = jsonencode({
    username = keycloak_user.automation.username
    password = ephemeral.random_password.automation.result
  })
  data_json_wo_version = var.keycloak_automation_password_revision
}

data "keycloak_role" "master_admin" {
  realm_id = "master"
  name     = "admin"
}

resource "keycloak_user_roles" "automation" {
  realm_id   = "master"
  user_id    = keycloak_user.automation.id
  role_ids   = [data.keycloak_role.master_admin.id]
  exhaustive = false
}

# The service account key Keycloak's database backs up to GCS with (see docs/backups-and-recovery.md)
module "keycloak_backup_credentials" {
  source = "../vault-k8s-secret"

  vault_secret_name             = "backups/service-account-key"
  vault_kv_mountpoint           = local.vault.kv_mountpoint
  vault_kubernetes_auth_backend = local.vault.kubernetes_auth_backend
  k8s_secret_name               = var.keycloak_backup_credentials_secret
  k8s_namespace                 = var.namespaces.keycloak
  k8s_service_account_name      = "keycloak-gcp-backup-creds"
  vault_role_name               = "keycloak-gcp-backup-creds"
}
