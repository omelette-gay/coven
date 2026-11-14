output "k8s_secret_name" {
  description = "Name of the Kubernetes Secret holding the client's credentials and Keycloak's endpoints"
  value       = kubernetes_secret_v1.this.metadata[0].name
}
