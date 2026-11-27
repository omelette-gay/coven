output "endpoint" {
  description = "Internal S3-compatible endpoint"
  value       = local.endpoint
}

output "public_endpoint" {
  description = "Public S3-compatible endpoint (https://<public_api.host>), or null if public_api isn't set. Presigned URLs for the public buckets must be made against this, as the signature covers the host"
  value       = var.public_api == null ? null : "https://${var.public_api.host}"
}

output "credentials_secret_name" {
  description = "Kubernetes Secret containing the RustFS credentials"
  value       = module.credentials.k8s_secret_name
}
