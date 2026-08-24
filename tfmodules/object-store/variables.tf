variable "name" {
  description = "Name used for the RustFS release, credentials, and buckets"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace in which RustFS is installed"
  type        = string
}

variable "storage_size" {
  description = "Longhorn volume size for RustFS"
  type        = string
  default     = "5Gi"
}

variable "buckets" {
  description = "Buckets to create in the object store"
  type        = set(string)
}
