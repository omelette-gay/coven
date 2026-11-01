variable "vault_secret_name" {
  description = "Path of the KV v2 secret in Vault, relative to the mount"
  type        = string
  validation {
    condition     = !startswith(var.vault_secret_name, "/") && !startswith(var.vault_secret_name, "data/") && !startswith(var.vault_secret_name, "${var.vault_kv_mountpoint}/")
    error_message = "vault_secret_name must be relative to the KV mount, without a leading slash, the mount name or data/."
  }
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes Secret created by External Secrets Operator"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the ServiceAccount, SecretStore, and Secret"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_namespace)) && length(var.k8s_namespace) <= 63
    error_message = "k8s_namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "k8s_service_account_name" {
  description = "ServiceAccount used by Vault Kubernetes authentication"
  type        = string
}

variable "vault_role_name" {
  description = "Vault policy and Kubernetes auth role name"
  type        = string
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount containing the secret"
  type        = string
  default     = "secret"
}

variable "vault_server" {
  description = "Vault address reachable from the Kubernetes cluster"
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200"
}

variable "refresh_interval" {
  description = "How often External Secrets Operator refreshes the Secret"
  type        = string
  default     = "1h"
  validation {
    condition     = can(regex("^(0|([0-9]+(\\.[0-9]+)?(ns|us|µs|ms|s|m|h))+)$", var.refresh_interval))
    error_message = "refresh_interval must be a Go duration, e.g. 1h or 30m, or 0 to never refresh."
  }
}
