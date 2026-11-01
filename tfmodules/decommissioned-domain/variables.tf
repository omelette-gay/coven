variable "name" {
  description = "Name of the namespace and Ingress holding the redirect, usually the domain with dots replaced by dashes"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "name must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "hostnames" {
  description = "Hostnames to redirect"
  type        = list(string)
  validation {
    condition     = length(var.hostnames) > 0 && alltrue([for hostname in var.hostnames : can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", hostname))])
    error_message = "hostnames must contain at least one lowercase hostname."
  }
}

variable "redirect_target" {
  description = "URL every request to the hostnames is permanently redirected to"
  type        = string
  validation {
    condition     = startswith(var.redirect_target, "https://")
    error_message = "redirect_target must be a full URL starting with https://."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the TLS certificates"
  type        = string
  default     = "letsencrypt"
}
