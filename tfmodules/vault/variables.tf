variable "namespace" {
  description = "Namespace to install Vault into. This module creates it"
  type        = string
  default     = "vault"
}

variable "host" {
  description = "Hostname for Vault"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificate. On the testlab this is the Vault issuer, which the platform stack makes, so the certificate is only issued once platform has been applied"
  type        = string
}

variable "data_storage_labels" {
  description = "Labels for Vault's data volume, e.g. to back it up with a Longhorn recurring job"
  type        = map(string)
  default     = {}
}

variable "host_aliases" {
  description = "Extra /etc/hosts entries, e.g. so it can reach Keycloak on the testlab, where Keycloak's hostname doesn't resolve inside the cluster"
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default = []
}
