terraform {
  # Write-only arguments (data_json_wo) need 1.11, and ephemeral resources 1.10
  required_version = ">= 1.11.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
  }
}

# Generated at apply time and never stored in state
ephemeral "random_password" "this" {
  for_each = var.keys

  length  = each.value
  special = false
}

# Write-only, so the values aren't stored in state. Unlike a Kubernetes Secret, this isn't read back either, which is why
# the Secret is made through Vault and External Secrets Operator rather than by Terraform (see docs/secrets.md).
# Terraform only writes the values when `revision` changes.
resource "vault_kv_secret_v2" "this" {
  mount = var.vault_kv_mountpoint
  name  = var.vault_secret_name

  data_json_wo         = jsonencode({ for key, password in ephemeral.random_password.this : key => password.result })
  data_json_wo_version = var.revision
}

module "secret" {
  source = "../vault-k8s-secret"

  # Refers to the secret in Vault, so that the sync is created after it
  vault_secret_name             = vault_kv_secret_v2.this.name
  vault_kv_mountpoint           = var.vault_kv_mountpoint
  vault_kubernetes_auth_backend = var.vault_kubernetes_auth_backend
  k8s_secret_name               = var.k8s_secret_name
  k8s_namespace                 = var.k8s_namespace
  k8s_service_account_name      = var.k8s_service_account_name
  vault_role_name               = var.vault_role_name
}
