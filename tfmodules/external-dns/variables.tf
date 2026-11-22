variable "namespace" {
  description = "Namespace to install external-dns into. This module creates it"
  type        = string
  default     = "external-dns"
}

variable "txt_owner_id" {
  description = "Owner ID external-dns writes in the TXT records that mark the records it manages. It never changes records without it, so changing this orphans every record it made"
  type        = string
}

variable "vault_secret_name" {
  description = "Vault KV secret holding the Hetzner API token, in the key api_token"
  type        = string
  default     = "gitops/hetzner"
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount holding the token. Pass the mount's path from the stack that makes it"
  type        = string
  default     = "secret"
}

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it"
  type        = string
  default     = "kubernetes"
}
