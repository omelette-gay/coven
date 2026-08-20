output "k8s_secret_name" {
  value = kubernetes_secret_v1.this.metadata[0].name
}
