variable "domain" {
  description = "Hostname used by GlitchTip for generated URLs and ingress"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.domain))
    error_message = "domain must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the GlitchTip TLS certificate"
  type        = string
  default     = "letsencrypt"
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
  default     = "omelette.gay"
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
  default     = "glitchtip@coven.local"
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sender_email))
    error_message = "sender_email must be an email address."
  }
}
