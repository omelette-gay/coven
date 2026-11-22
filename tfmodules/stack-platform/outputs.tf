output "vault_kv_mountpoint" {
  description = "Path of Vault's KV v2 mount, where secrets live"
  value       = vault_mount.secret.path
}

output "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method"
  value       = vault_auth_backend.kubernetes.path
}

output "vault_kubernetes_secret_backend" {
  description = "Path of Vault's Kubernetes secrets engine, which issues cluster credentials"
  value       = vault_kubernetes_secret_backend.kubernetes.path
}

output "vault_github_auth_backend" {
  description = "Path of Vault's GitHub Actions auth method"
  value       = vault_jwt_auth_backend.github.path
}
