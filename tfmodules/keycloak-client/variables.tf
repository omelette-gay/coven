variable "keycloak_realm" {
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

variable "keycloak_url" {
  description = "Keycloak base URL, including its base path if it has one (e.g. https://auth.coven.omelette.gay/auth)"
  type        = string
  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must start with https:// and have no trailing slash."
  }
}

variable "role_groups" {
  description = "Existing groups to grant each client role to, as a map of role name to group names (e.g. { admin = [\"admins\"] })"
  type        = map(list(string))
  default     = {}
  validation {
    condition     = alltrue([for role in keys(var.role_groups) : contains(var.client_roles, role)])
    error_message = "Every key of role_groups must be one of client_roles."
  }
}

variable "group_ids" {
  description = "IDs of groups in role_groups that are made in the same stack, as a map of group name to ID, so they don't have to exist before the stack is planned. Other groups are looked up by name"
  type        = map(string)
  default     = {}
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
  description = "Name of the Kubernetes Secret containing the client's credentials and Keycloak's endpoints (see the README)"
  type        = string
}

variable "secret_revision" {
  description = "Increase this to rotate the client secret: it writes a new one to Keycloak and the Kubernetes Secret together, and rewrites the rest of the Secret's keys. Both are write-only, so Terraform only writes them when this changes. An app that keeps its own copy of the secret needs updating too"
  type        = number
  default     = 1
  validation {
    condition     = var.secret_revision >= 1 && floor(var.secret_revision) == var.secret_revision
    error_message = "secret_revision must be a whole number, 1 or more."
  }
}
