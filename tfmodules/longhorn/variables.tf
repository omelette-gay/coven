variable "namespace" {
  description = "Namespace to install Longhorn into. This module creates it"
  type        = string
  default     = "longhorn-system"
}

variable "monitoring_namespace" {
  description = "Namespace Prometheus runs in, which Longhorn's network policy lets scrape its metrics"
  type        = string
}

variable "over_provisioning_percentage" {
  description = "How much more storage Longhorn lets volumes ask for than is available, as a percentage"
  type        = number
  default     = 100
  validation {
    condition     = var.over_provisioning_percentage >= 100 && floor(var.over_provisioning_percentage) == var.over_provisioning_percentage
    error_message = "over_provisioning_percentage must be a whole number, 100 or more."
  }
}

variable "allow_degraded_volumes" {
  description = "Whether Longhorn can create volumes with fewer than the default 2 replicas. Needed on a single-node cluster such as the testlab"
  type        = bool
  default     = false
}

variable "backup_bucket" {
  description = "GCS bucket (in europe-west2) Longhorn backs volumes up to, or null for no off-site backups (as on the testlab)"
  type        = string
  default     = null
}

variable "backup_credentials_secret" {
  description = "Secret holding the credentials for backing up to GCS, which the platform stack syncs from Vault. Backups fail until it exists. Only used with a backup_bucket"
  type        = string
  default     = null
}
