output "namespace" {
  description = "Namespace Vikunja runs in"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
