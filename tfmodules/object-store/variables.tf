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

variable "existing_credentials" {
  description = "RustFS credentials to write instead of generating new ones. Only for importing an existing object store without rotating its credentials"
  type = object({
    access_key = string
    secret_key = string
  })
  default   = null
  sensitive = true
  ephemeral = true
}
