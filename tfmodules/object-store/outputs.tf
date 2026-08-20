output "endpoint" {
  description = "Internal S3-compatible endpoint"
  value       = local.endpoint
}

output "credentials_secret_name" {
  description = "Kubernetes Secret containing the RustFS credentials"
  value       = kubernetes_secret_v1.credentials.metadata[0].name
}
