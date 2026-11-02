output "k8s_secret_name" {
  # Refers to the ExternalSecret so that anything using the name is created after it
  value = kubernetes_manifest.external_secret.manifest.spec.target.name
}
