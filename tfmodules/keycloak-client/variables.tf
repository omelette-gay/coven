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
}

variable "client_roles" {
  description = "Client roles to create"
  type        = list(string)
  default     = []
}

variable "k8s_namespace" {
  description = "Namespace for the client credentials Secret"
  type        = string
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes Secret containing client_id and client_secret"
  type        = string
}

variable "existing_client_secret" {
  description = "Client secret to write instead of generating a new one. Only for importing an existing client without rotating its secret"
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}
