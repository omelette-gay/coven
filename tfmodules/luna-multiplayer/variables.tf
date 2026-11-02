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

variable "chart_version" {
  description = "Version of the luna-multiplayer Helm chart to install. Bump it to upgrade"
  type        = string
}

variable "vault_secret_name" {
  description = "Path of the KV v2 secret in Vault, relative to the mount, that the chart reads secrets from (the chart's storage.mergeConfigFromExternalSecret.remoteKey)"
  type        = string
}

variable "values" {
  description = "Helm values for the chart, as YAML strings. Load files with file(), not templatefile(), as they can contain External Secrets templates such as {{ .server_password }}"
  type        = list(string)
}
