variable "realm_id" {
  description = "Keycloak realm containing the client"
  type        = string
}

variable "client_id" {
  description = "OpenID Connect client ID"
  type        = string
}

variable "client_name" {
  description = "Human-readable client name"
  type        = string
}

variable "valid_redirect_uris" {
  description = "Allowed OpenID Connect redirect URIs"
  type        = list(string)
  validation {
    condition     = length(var.valid_redirect_uris) > 0 && alltrue([for uri in var.valid_redirect_uris : startswith(uri, "https://")])
    error_message = "valid_redirect_uris must contain at least one URI, each starting with https://."
  }
}

variable "client_roles" {
  description = "Client roles to create"
  type        = list(string)
  default     = []
}

variable "k8s_namespace" {
  description = "Namespace for the client credentials Secret"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_namespace)) && length(var.k8s_namespace) <= 63
    error_message = "k8s_namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes Secret containing client_id and client_secret"
  type        = string
}
