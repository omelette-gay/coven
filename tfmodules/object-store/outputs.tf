output "endpoint" {
  description = "Internal S3-compatible endpoint"
  value       = local.endpoint
}

output "credentials_secret_name" {
  description = "Kubernetes Secret containing the RustFS credentials"
  value       = module.credentials.k8s_secret_name
}
