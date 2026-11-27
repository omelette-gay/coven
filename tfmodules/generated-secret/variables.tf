variable "keys" {
  description = "Secret values to generate, as a map of key name to length. They're random letters and digits, and the key names are the keys of the Kubernetes Secret"
  type        = map(number)
  default     = {}
  validation {
    condition     = alltrue([for length in values(var.keys) : length >= 16 && floor(length) == length])
    error_message = "Each length in keys must be a whole number of at least 16."
  }
}

variable "hex_keys" {
  description = "Secret values to generate as random bytes in lowercase hex, for things that need a key of an exact size (e.g. 32 for an AES-256 key, which is 64 hex characters), as a map of key name to number of bytes"
  type        = map(number)
  default     = {}
  validation {
    condition     = alltrue([for length in values(var.hex_keys) : length >= 16 && floor(length) == length]) && length(var.keys) + length(var.hex_keys) > 0 && length(setintersection(keys(var.keys), keys(var.hex_keys))) == 0
    error_message = "Each length in hex_keys must be a whole number of bytes, at least 16. There must be at least one key in keys or hex_keys, and none in both."
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

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it, so the role is created after it"
  type        = string
  default     = "kubernetes"
}
