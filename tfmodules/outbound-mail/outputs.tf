output "smtp_host" {
  description = "Address apps in the cluster send mail through"
  value       = "${helm_release.mail.name}.${helm_release.mail.namespace}.svc.cluster.local"
}

output "smtp_port" {
  description = "Port apps in the cluster send mail through"
  value       = 587
}
