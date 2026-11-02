output "k8s_secret_name" {
  # Refers to the ExternalSecret so that anything using the name is created after it. Null if no ExternalSecret was
  # created.
  value = one(kubernetes_manifest.external_secret[*].manifest.spec.target.name)
}

output "secret_store_name" {
  value = kubernetes_manifest.secret_store.manifest.metadata.name
}
