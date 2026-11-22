variable "namespace" {
  description = "Namespace to install cert-manager into. This module creates it"
  type        = string
  default     = "cert-manager"
}

variable "acme_email" {
  description = "Email address for the Let's Encrypt account, which Let's Encrypt sends expiry warnings to"
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acme_email))
    error_message = "acme_email must be an email address."
  }
}

variable "letsencrypt_server" {
  description = "ACME server for the Let's Encrypt ClusterIssuer. Defaults to staging, so only production uses up real rate limits"
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
  validation {
    condition     = startswith(var.letsencrypt_server, "https://")
    error_message = "letsencrypt_server must start with https://."
  }
}
