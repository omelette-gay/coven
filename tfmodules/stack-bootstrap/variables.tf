variable "cluster_domain" {
  description = "Domain the cluster's own services live under, e.g. coven.omelette.gay"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificates of the services installed here (Grafana, Vault and Keycloak). On the testlab this is the Vault issuer, which platform creates, so these certificates are only issued once platform has been applied"
  type        = string
}

variable "letsencrypt_server" {
  description = "ACME server for the Let's Encrypt ClusterIssuer. Defaults to staging, so only production uses up real rate limits"
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "host_aliases" {
  description = "Extra /etc/hosts entries for Grafana and Vault, so they can reach Keycloak on the testlab, where its hostname doesn't resolve in the cluster"
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default = []
}

variable "longhorn_over_provisioning_percentage" {
  description = "How much more storage Longhorn lets volumes ask for than is available, as a percentage"
  type        = number
  default     = 100
}

variable "longhorn_allow_degraded_volumes" {
  description = "Whether Longhorn can create volumes with fewer than the default 2 replicas. Needed on a single-node cluster such as the testlab"
  type        = bool
  default     = false
}

variable "keycloak_bootstrap_admin_password" {
  description = "Only set this on the first apply of a fresh cluster. Keycloak creates a temporary admin, `bootstrap-admin`, with this password on its first start, which platform uses to create the realm and Terraform's own user. Delete that admin and unset this once platform has been applied (see docs/bootstrapping.md). Ignored once Keycloak has an admin"
  type        = string
  default     = null
  sensitive   = true
}
