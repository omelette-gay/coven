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

variable "glitchtip_keycloak_secret_revision" {
  description = "Increase this to rotate GlitchTip's Keycloak client secret (see the glitchtip module)"
  type        = number
  default     = 1
}
