variable "namespace" {
  description = "Namespace to install Loki and Alloy into. It must already exist, and be the namespace Grafana runs in, as Loki's data source is found by Grafana's sidecar there"
  type        = string
  default     = "monitoring"
}

variable "storage_size" {
  description = "Size of the volume Loki keeps its logs on"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.storage_size))
    error_message = "storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "chunks_cache_memory" {
  description = "Memory for Loki's chunks cache, in MB"
  type        = number
  default     = 4096
  validation {
    condition     = var.chunks_cache_memory > 0 && floor(var.chunks_cache_memory) == var.chunks_cache_memory
    error_message = "chunks_cache_memory must be a whole number of MB."
  }
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount for the object store's keys. Pass the mount's path from the stack that makes it"
  type        = string
  default     = "secret"
}

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it"
  type        = string
  default     = "kubernetes"
}
