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

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job to back RustFS's volume up with, e.g. nightly-backup. If set, the module creates the volume itself so it can be labelled; if null, the RustFS chart creates it and it isn't backed up. Changing this on an existing store switches RustFS to a new, empty volume"
  type        = string
  default     = null
}

variable "buckets" {
  description = "Buckets to create in the object store"
  type        = set(string)
  validation {
    condition     = length(var.buckets) > 0 && alltrue([for bucket in var.buckets : can(regex("^[a-z0-9][-a-z0-9]{1,61}[a-z0-9]$", bucket)) && length("create-${var.name}-bucket-${bucket}") <= 63])
    error_message = "buckets must contain at least one bucket name of 3-63 lowercase letters, digits and hyphens, short enough that create-<name>-bucket-<bucket> fits in 63 characters."
  }
}

variable "versioned_buckets" {
  description = "Buckets in `buckets` to turn versioning on for, so overwritten and deleted objects keep their old versions (Grist requires this). Removing a bucket from this list doesn't turn versioning off"
  type        = set(string)
  default     = []
  validation {
    condition     = length(setsubtract(var.versioned_buckets, var.buckets)) == 0
    error_message = "versioned_buckets must only contain buckets that are also in buckets."
  }
}

variable "public_api" {
  description = "Serve the S3 API on a public hostname, for apps whose users fetch files directly: with presigned URLs, or anonymously from `public_read_buckets`. Only `buckets` are routed. If `cors_allowed_origins` is set, they get CORS rules allowing those origins. `public_read_buckets` (a subset of `buckets`) let anyone fetch an object by its key, without listing the bucket; the rest need a signature. Removing a bucket, or the whole setting, removes its route but not its CORS rules or anonymous read policy"
  type = object({
    host                 = string
    cluster_issuer       = string
    buckets              = set(string)
    cors_allowed_origins = optional(list(string), [])
    public_read_buckets  = optional(set(string), [])
  })
  default = null
  validation {
    condition     = var.public_api == null || can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.public_api.host))
    error_message = "public_api.host must be a bare hostname, without https:// or a trailing slash."
  }
  validation {
    condition     = var.public_api == null || (length(var.public_api.buckets) > 0 && length(setsubtract(var.public_api.buckets, var.buckets)) == 0)
    error_message = "public_api.buckets must contain at least one bucket, and only buckets that are also in buckets."
  }
  validation {
    condition     = var.public_api == null || alltrue([for origin in var.public_api.cors_allowed_origins : can(regex("^https://([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?(:[0-9]+)?$", origin))])
    error_message = "public_api.cors_allowed_origins must each be https://<hostname> with an optional port and no path or trailing slash."
  }
  validation {
    condition     = var.public_api == null || length(setsubtract(var.public_api.public_read_buckets, var.public_api.buckets)) == 0
    error_message = "public_api.public_read_buckets must only contain buckets that are also in public_api.buckets."
  }
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount for the secret. Pass the mount's path from the stack that makes it, so the secret is written after it"
  type        = string
  default     = "secret"
}

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it, so the role is created after it"
  type        = string
  default     = "kubernetes"
}
