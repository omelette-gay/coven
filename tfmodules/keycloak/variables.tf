variable "namespace" {
  description = "Namespace to install Keycloak into. This module creates it"
  type        = string
  default     = "keycloak"
}

variable "url" {
  description = "Keycloak's base URL, including the path it's served under, e.g. https://auth.coven.omelette.gay/auth"
  type        = string
  validation {
    condition     = can(regex("^https://[^/]+/[^/].*[^/]$", var.url))
    error_message = "url must start with https://, include a path such as /auth, and have no trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificate. On the testlab this is the Vault issuer, which the platform stack makes, so the certificate is only issued once platform has been applied"
  type        = string
}

variable "bootstrap_admin_username" {
  description = "Username of the temporary admin Keycloak creates on its first start, if bootstrap_admin_password is set. The platform stack's root logs in as it for its first apply"
  type        = string
}

variable "bootstrap_admin_password" {
  description = "Only set this on the first apply of a fresh cluster. Keycloak creates a temporary admin with this password on its first start, which the platform stack uses to create the realm and Terraform's own user. Delete that admin and unset this once platform has been applied (see docs/bootstrapping.md). Ignored once Keycloak has an admin"
  type        = string
  default     = null
  sensitive   = true
}

variable "backup_bucket" {
  description = "GCS bucket the database backs up to, or null for no backups (as on the testlab)"
  type        = string
  default     = null
}

variable "backup_credentials_secret" {
  description = "Secret holding the GCP service account key the database backs up with, which the platform stack syncs from Vault. Backups fail until it exists. Only used with a backup_bucket"
  type        = string
  default     = null
}

variable "postgresql_image_catalog" {
  description = "ClusterImageCatalog the database takes its PostgreSQL image from (see ADR 007)"
  type        = string
}
