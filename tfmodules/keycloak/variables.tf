variable "namespace" {
  description = "Namespace to install Keycloak into. This module creates it"
  type        = string
  default     = "keycloak"
}

variable "host" {
  description = "Hostname for Keycloak, which serves it under /auth"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificate. On the testlab this is the Vault issuer, which the platform stack makes, so the certificate is only issued once platform has been applied"
  type        = string
}

variable "bootstrap_admin_username" {
  description = "Username of the temporary admin Keycloak creates on its first start, if bootstrap_admin_password is set"
  type        = string
  default     = "temp-admin"
}

variable "bootstrap_admin_password" {
  description = "Only set this on the first apply of a fresh cluster. Keycloak creates a temporary admin with this password on its first start, which the platform stack uses to create the realm and Terraform's own user. Delete that admin and unset this once platform has been applied (see docs/bootstrapping.md). Ignored once Keycloak has an admin"
  type        = string
  default     = null
  sensitive   = true
}
