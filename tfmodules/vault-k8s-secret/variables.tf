variable "vault_secret_name" {
  description = "Path of the KV v2 secret in Vault, relative to the mount"
  type        = string
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes Secret created by External Secrets Operator"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the ServiceAccount, SecretStore, and Secret"
  type        = string
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
}
