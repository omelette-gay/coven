variable "keys" {
  description = "Secret values to generate, as a map of key name to length. They're random letters and digits, and the key names are the keys of the Kubernetes Secret"
  type        = map(number)
  validation {
    condition     = length(var.keys) > 0 && alltrue([for length in values(var.keys) : length >= 16 && floor(length) == length])
    error_message = "keys must have at least one key, and each length must be a whole number of at least 16."
  }
}

variable "vault_secret_name" {
  description = "Path of the KV v2 secret in Vault to write, relative to the mount"
  type        = string
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount to write the secret to"
  type        = string
  default     = "secret"
}

variable "revision" {
  description = "Increase this to generate new values: Terraform writes them to Vault only when it changes, and External Secrets Operator then updates the Kubernetes Secret within its refresh interval. Anything that reads the Secret only when it starts needs restarting afterwards"
  type        = number
  default     = 1
  validation {
    condition     = var.revision >= 1 && floor(var.revision) == var.revision
    error_message = "revision must be a whole number, 1 or more."
  }
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes Secret that External Secrets Operator creates. It mustn't already exist, as ESO won't take over a Secret it didn't create"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the Secret"
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
