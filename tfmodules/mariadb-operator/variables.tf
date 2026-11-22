variable "namespace" {
  description = "Namespace to install the operator into. This module creates it"
  type        = string
  default     = "mariadb-system"
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the operator's webhook certificate. Pass the issuer's name from the resource that makes it, so it exists first"
  type        = string
}
