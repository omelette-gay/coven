output "k8s_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount the pods should run as"
  value       = kubernetes_service_account_v1.this.metadata[0].name
}

output "config_map_name" {
  description = "Name of the ConfigMap holding credentials.json, audience and token_path"
  value       = kubernetes_config_map_v1.this.metadata[0].name
}

output "audience" {
  description = "Audience for the pods' projected service account token"
  value       = kubernetes_config_map_v1.this.data["audience"]
}
