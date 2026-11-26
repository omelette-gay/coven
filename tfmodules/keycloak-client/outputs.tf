output "k8s_secret_name" {
  description = "Name of the Kubernetes Secret holding the client's credentials and Keycloak's endpoints"
  value       = kubernetes_secret_v1.this.metadata[0].name
}

output "role_ids" {
  description = "IDs of the client roles, as a map of role name to ID, for granting them to groups (see docs/sso.md)"
  value       = { for name, role in keycloak_role.this : name => role.id }
}
