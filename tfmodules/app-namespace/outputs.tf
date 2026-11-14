output "name" {
  description = "Name of the namespace. Use this, rather than repeating the name, so anything in the namespace is created after it"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
