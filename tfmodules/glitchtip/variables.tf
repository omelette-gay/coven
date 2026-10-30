variable "domain" {
  description = "Hostname used by GlitchTip for generated URLs and ingress"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the GlitchTip TLS certificate"
  type        = string
  default     = "letsencrypt"
}

variable "keycloak_url" {
  description = "Keycloak base URL"
  type        = string
}

variable "keycloak_realm" {
  description = "Keycloak realm used for GlitchTip SSO"
  type        = string
  default     = "omelette.gay"
}

variable "postgresql_instances" {
  description = "Number of CNPG PostgreSQL instances"
  type        = number
  default     = 1
}

variable "postgresql_storage_size" {
  description = "Persistent storage size for PostgreSQL"
  type        = string
  default     = "5Gi"
}

variable "sender_email" {
  description = "email address to send emails from"
  default     = "glitchtip@coven.local"
}

variable "existing_secrets" {
  description = "Secrets to write instead of generating new ones. Only for importing an existing GlitchTip without rotating its secrets"
  type = object({
    secret_key              = string
    keycloak_client_secret  = string
    object_store_access_key = string
    object_store_secret_key = string
  })
  default   = null
  sensitive = true
  ephemeral = true
}
