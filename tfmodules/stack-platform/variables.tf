variable "keycloak_url" {
  description = "Keycloak base URL, including the base path"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for TLS certificates"
  type        = string
}

variable "glitchtip_domain" {
  description = "Hostname for GlitchTip"
  type        = string
}

variable "glitchtip_postgresql_instances" {
  description = "Number of CNPG PostgreSQL instances for GlitchTip"
  type        = number
}

variable "glitchtip_sender_email" {
  description = "Email address GlitchTip sends emails from"
  type        = string
}

variable "glitchtip_existing_secrets" {
  description = "Secrets for GlitchTip to write instead of generating new ones. Only for importing an existing GlitchTip without rotating its secrets"
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
