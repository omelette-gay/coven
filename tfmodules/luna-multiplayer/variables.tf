variable "instance_name" {
  description = "Name of the Helm release, and of this server instance (e.g. girlsclub)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance_name))
    error_message = "instance_name must be a DNS label (lowercase letters, digits and hyphens)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to create and install the chart into"
  type        = string
  default     = "luna-multiplayer"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "vault_secret_name" {
  description = "Path of the KV v2 secret in Vault, relative to the mount, that holds server_password. The server config can refer to it as {{ .server_password }}"
  type        = string
}

variable "host" {
  description = "Hostname that the server's web interface is served on, with a certificate from cert-manager. The web interface only returns the server's status as JSON. If null, no ingress is created"
  type        = string
  default     = null
  validation {
    condition     = var.host == null || can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.host))
    error_message = "host must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the web interface's TLS certificate, if it has a hostname"
  type        = string
  default     = "letsencrypt"
}

variable "cpu_request" {
  description = "CPU the pod requests, as a Kubernetes quantity. There is no CPU limit, so the server can burst. The default is well above what the server has been observed to use"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory the pod requests, as a Kubernetes quantity. There is no limit. The default is about double what the server has been observed to use"
  type        = string
  default     = "256Mi"
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job to label the universe and plugin volumes with, e.g. nightly-backup. If null, no Longhorn labels are set"
  type        = string
  default     = null
}

variable "preferred_node_labels" {
  description = "Node labels to prefer running the server on, e.g. { \"coven.omelette.gay/location\" = \"xdc\" }"
  type        = map(string)
  default     = {}
}

variable "config" {
  description = "The server's config files that contain secrets, as a map of file name to contents (e.g. GeneralSettings.xml). They are stored in a Secret and copied over the chart's defaults, and files that aren't set use the chart's defaults. Contents can refer to keys of the Vault secret, e.g. {{ .server_password }}, which is a template filled in by External Secrets, so don't run them through templatefile()"
  type        = map(string)
  default     = {}
}
