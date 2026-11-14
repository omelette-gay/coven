output "k8s_secret_name" {
  description = "Name of the Kubernetes Secret that External Secrets Operator creates, or null if create_external_secret is false"
  # Refers to the ExternalSecret so that anything using the name is created after it. Null if no ExternalSecret was
  # created.
  value = one(kubernetes_manifest.external_secret[*].manifest.spec.target.name)
}

output "secret_store_name" {
  description = "Name of the SecretStore that reads the Vault secret, for an ExternalSecret that something else creates"
  value       = kubernetes_manifest.secret_store.manifest.metadata.name
}
