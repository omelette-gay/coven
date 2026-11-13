output "k8s_secret_name" {
  description = "Name of the Kubernetes Secret that External Secrets Operator creates"
  # Refers to the ExternalSecret, so anything using the name is created after the sync. The Secret itself is made by ESO
  # a moment later, so something that needs it at once should be able to wait for it
  value = module.secret.k8s_secret_name
}
