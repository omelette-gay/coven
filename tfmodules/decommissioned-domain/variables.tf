variable "name" {
  description = "Name of the namespace and Ingress holding the redirect, usually the domain with dots replaced by dashes"
  type        = string
}

variable "hostnames" {
  description = "Hostnames to redirect"
  type        = list(string)
}

variable "redirect_target" {
  description = "URL every request to the hostnames is permanently redirected to"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for the TLS certificates"
  type        = string
  default     = "letsencrypt"
}
