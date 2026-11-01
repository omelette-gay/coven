variable "name" {
  description = "Name used for the RustFS release, credentials, and buckets"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "name must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace in which RustFS is installed"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "storage_size" {
  description = "Longhorn volume size for RustFS"
  type        = string
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.storage_size))
    error_message = "storage_size must be a Kubernetes quantity, e.g. 5Gi."
  }
}

variable "buckets" {
  description = "Buckets to create in the object store"
  type        = set(string)
  validation {
    condition     = length(var.buckets) > 0 && alltrue([for bucket in var.buckets : can(regex("^[a-z0-9][-a-z0-9]{1,61}[a-z0-9]$", bucket)) && length("create-${var.name}-bucket-${bucket}") <= 63])
    error_message = "buckets must contain at least one bucket name of 3-63 lowercase letters, digits and hyphens, short enough that create-<name>-bucket-<bucket> fits in 63 characters."
  }
}
