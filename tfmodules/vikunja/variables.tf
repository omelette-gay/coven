variable "domain" {
  description = "Hostname Vikunja is served on"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.domain))
    error_message = "domain must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the Vikunja TLS certificate"
  type        = string
  default     = "letsencrypt"
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
  default     = "omelette.gay"
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
  description = "Number of CNPG PostgreSQL instances. Keep it at 2 or more on coven, like Keycloak and Planka, as the cluster chart's alerts expect a standby. The single-node testlab can use 1"
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
  description = "Path in backup_bucket for the database's backups. Barman won't archive into a path that already holds another cluster's backups, so each environment needs its own"
  type        = string
  default     = "/cnpg/vikunja/"
  validation {
    condition     = startswith(var.backup_path, "/") && endswith(var.backup_path, "/")
    error_message = "backup_path must start and end with a slash, e.g. /cnpg/vikunja/."
  }
}

variable "attachments_storage_size" {
  description = "Size of the volume holding task attachments and avatars"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.attachments_storage_size))
    error_message = "attachments_storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job to label the attachments volume with, e.g. nightly-backup. If null, no Longhorn labels are set"
  type        = string
  default     = null
}

variable "sender_email" {
  description = "Email address Vikunja sends emails from"
  type        = string
  default     = "vikunja@coven.local"
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.sender_email))
    error_message = "sender_email must be an email address."
  }
}

variable "host_aliases" {
  description = "Extra /etc/hosts entries for the Vikunja pod, as a map of IP address to hostnames. Only for the testlab, where cluster DNS can't resolve Keycloak's hostname"
  type        = map(list(string))
  default     = {}
}

variable "trusted_ca_secret_name" {
  description = "Secret in the vikunja namespace whose ca.crt Vikunja should trust as well as the image's CA bundle. Only for the testlab, where Keycloak's certificate comes from Vault's private CA"
  type        = string
  default     = null
}
