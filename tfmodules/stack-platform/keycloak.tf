locals {
  keycloak_realm = "omelette.gay"
}

# The realm everyone logs in to things with. Admin accounts for Keycloak itself are in the master realm. Who can use what
# is up to each app (see docs/sso.md).
resource "keycloak_realm" "omelette_gay" {
  realm       = local.keycloak_realm
  internal_id = "omelette-gay"
  enabled     = true

  user_managed_access         = true
  default_signature_algorithm = "RS256"

  smtp_server {
    from = "keycloak@${var.cluster_domain}"
    host = local.smtp_host
    port = local.smtp_port
  }
}

# Chris and Meg, who get admin roles in the apps that map them to this group
resource "keycloak_group" "admins" {
  realm_id = keycloak_realm.omelette_gay.id
  name     = "admins"
}

# The user Terraform logs in to Keycloak as, through the credentials in Vault at gitops/keycloak-master-credentials. On a
# fresh cluster, platform's first apply logs in as Keycloak's temporary admin instead (see docs/bootstrapping.md).
resource "keycloak_user" "automation" {
  realm_id = "master"
  username = "ansible-automation"
  enabled  = true
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

  vault_secret_name        = "backups/service-account-key"
  k8s_secret_name          = "keycloak-gcp-backup-creds"
  k8s_namespace            = "keycloak"
  k8s_service_account_name = "keycloak-gcp-backup-creds"
  vault_role_name          = "keycloak-gcp-backup-creds"
}

resource "kubernetes_manifest" "keycloak_probe" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "Probe"
    metadata = {
      name      = "keycloak-https"
      namespace = "keycloak"
    }
    spec = {
      interval = "60s"
      module   = "http_2xx"
      prober   = local.blackbox_prober
      targets = {
        staticConfig = {
          static = ["${var.keycloak_url}/realms/master/"]
        }
      }
    }
  }
}
