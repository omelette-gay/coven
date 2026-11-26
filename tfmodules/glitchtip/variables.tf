variable "host" {
  description = "Hostname used by GlitchTip for generated URLs and ingress"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.host))
    error_message = "domain must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the GlitchTip TLS certificate"
  type        = string
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must start with https:// and have no trailing slash."
  }
}

variable "keycloak_realm" {
  description = "Keycloak realm used for GlitchTip SSO"
  type        = string
}

variable "keycloak_secret_revision" {
  description = "Increase this to rotate GlitchTip's Keycloak client secret. It writes a new secret to Keycloak and the Kubernetes Secret, then runs the Job that copies it into GlitchTip's database again, so SSO only breaks while that happens"
  type        = number
  default     = 1
  validation {
    condition     = var.keycloak_secret_revision >= 1 && floor(var.keycloak_secret_revision) == var.keycloak_secret_revision
    error_message = "keycloak_secret_revision must be a whole number, 1 or more."
  }
}

variable "postgresql_instances" {
  description = "Number of CNPG PostgreSQL instances"
  type        = number
  default     = 1
  validation {
    condition     = var.postgresql_instances >= 1 && floor(var.postgresql_instances) == var.postgresql_instances
    error_message = "postgresql_instances must be a whole number of at least 1."
  }
}

variable "postgresql_storage_size" {
  description = "Persistent storage size for PostgreSQL"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.postgresql_storage_size))
    error_message = "postgresql_storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "sender_email" {
  description = "Email address GlitchTip sends emails from"
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sender_email))
    error_message = "sender_email must be an email address."
  }
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount for GlitchTip's secrets. Pass the mount's path from the stack that makes it, so the secrets are written after it"
  type        = string
  default     = "secret"
}

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it, so the roles are created after it"
  type        = string
  default     = "kubernetes"
}

variable "smtp_host" {
  description = "SMTP relay GlitchTip sends mail through (the platform stack's outbound mail)"
  type        = string
}

variable "smtp_port" {
  description = "Port of the SMTP relay"
  type        = number
}

variable "blackbox_prober" {
  description = "Blackbox exporter that probes GlitchTip over HTTPS (installed by the bootstrap stack)"
  type = object({
    url  = string
    path = string
  })
}

variable "postgresql_image_catalog" {
  description = "ClusterImageCatalog the database takes its PostgreSQL image from (see ADR 007)"
  type        = string
}

variable "backup_bucket" {
  description = "GCS bucket the database's base backups and WAL are archived to, under /cnpg/glitchtip/, or null for no backups (as on the testlab)"
  type        = string
  default     = null
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job to back RustFS's volume (uploaded files such as source maps) up with, e.g. nightly-backup, or null for no backups"
  type        = string
  default     = null
}
