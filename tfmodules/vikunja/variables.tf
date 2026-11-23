variable "namespace" {
  description = "Kubernetes namespace to create and install Vikunja into. Also used for the Vault secret path and roles, the Keycloak client ID and the default backup path, so a second install in another namespace doesn't clash with the first. Changing it on an existing install creates a new, empty one"
  type        = string
  default     = "vikunja"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "host" {
  description = "Hostname Vikunja is served on"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.host))
    error_message = "domain must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the Vikunja TLS certificate"
  type        = string
}

variable "keycloak_url" {
  description = "Keycloak base URL, including its base path if it has one (e.g. https://auth.coven.omelette.gay/auth)"
  type        = string
  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must start with https:// and have no trailing slash."
  }
}

variable "keycloak_realm" {
  description = "Keycloak realm used for Vikunja SSO"
  type        = string
}

variable "keycloak_secret_revision" {
  description = "Increase this to rotate Vikunja's Keycloak client secret. It writes a new secret to Keycloak and the Kubernetes Secret, and restarts Vikunja so it reads the new one"
  type        = number
  default     = 1
  validation {
    condition     = var.keycloak_secret_revision >= 1 && floor(var.keycloak_secret_revision) == var.keycloak_secret_revision
    error_message = "keycloak_secret_revision must be a whole number, 1 or more."
  }
}

variable "postgresql_instances" {
  description = "Number of CNPG PostgreSQL instances. Keep it at 2 or more on coven, like Keycloak, as the cluster chart's alerts expect a standby. The single-node testlab can use 1"
  type        = number
  default     = 2
  validation {
    condition     = var.postgresql_instances >= 1 && floor(var.postgresql_instances) == var.postgresql_instances
    error_message = "postgresql_instances must be a whole number of at least 1."
  }
}

variable "postgresql_storage_size" {
  description = "Persistent storage size for each PostgreSQL instance"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.postgresql_storage_size))
    error_message = "postgresql_storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "backup_bucket" {
  description = "GCS bucket the database's base backups and WAL are archived to"
  type        = string
  default     = "coven-backups"
}

variable "backup_path" {
  description = "Path in backup_bucket for the database's backups. Barman won't archive into a path that already holds another cluster's backups, so each environment and install needs its own. Defaults to /cnpg/<namespace>/"
  type        = string
  default     = null
  validation {
    condition     = var.backup_path == null || (startswith(coalesce(var.backup_path, "/"), "/") && endswith(coalesce(var.backup_path, "/"), "/"))
    error_message = "backup_path must start and end with a slash, e.g. /cnpg/vikunja/."
  }
}

variable "attachments_storage_size" {
  description = "Size of RustFS's volume, which holds task attachments, avatars and backgrounds"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.attachments_storage_size))
    error_message = "attachments_storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job to back RustFS's volume (the attachments) up with, e.g. nightly-backup. If null, attachments aren't backed up. Set it before first deploying: changing it later switches RustFS to a new, empty volume"
  type        = string
  default     = null
}

variable "sender_email" {
  description = "Email address Vikunja sends emails from"
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sender_email))
    error_message = "sender_email must be an email address."
  }
}

variable "host_aliases" {
  description = "Extra /etc/hosts entries for the Vikunja pod. Only for the testlab, where cluster DNS can't resolve Keycloak's hostname"
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default = []
}

variable "trusted_ca_secret_name" {
  description = "Secret in the vikunja namespace whose ca.crt Vikunja should trust as well as the image's CA bundle. Only for the testlab, where Keycloak's certificate comes from Vault's private CA"
  type        = string
  default     = null
}

variable "smtp_host" {
  description = "SMTP relay Vikunja sends mail through (the platform stack's outbound mail)"
  type        = string
}

variable "smtp_port" {
  description = "Port of the SMTP relay"
  type        = number
}

variable "blackbox_prober" {
  description = "Blackbox exporter that probes Vikunja over HTTPS (installed by the bootstrap stack)"
  type = object({
    url  = string
    path = string
  })
}
