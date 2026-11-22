variable "name" {
  description = "Name of the namespace"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "name must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "ghcr_secret_name" {
  description = "Name of a Secret to create in the namespace holding the GitHub Container Registry credentials, in the format imagePullSecrets expects. If null, the namespace can't pull private images"
  type        = string
  default     = null
  validation {
    condition     = var.ghcr_secret_name == null || (can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", var.ghcr_secret_name)) && length(var.ghcr_secret_name) <= 253)
    error_message = "ghcr_secret_name must be a valid Kubernetes Secret name (lowercase letters, digits, hyphens and dots, at most 253 characters)."
  }
}

variable "ghcr_vault_secret_name" {
  description = "Path of the KV v2 secret in Vault, relative to the mount, that holds the GHCR credentials (user and password)"
  type        = string
  default     = "repositories/ghcr"
}

variable "ghcr_policy_name" {
  description = "Vault policy that allows reading the GHCR credentials. Shared by every namespace, and created by the platform stack (tfmodules/stack-platform/vault.tf)"
  type        = string
  default     = "ghcr-creds-read"
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount containing the GHCR credentials"
  type        = string
  default     = "secret"
}

variable "vault_server" {
  description = "Vault address reachable from the Kubernetes cluster"
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200"
}
