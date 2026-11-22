variable "cluster_domain" {
  description = "Domain the cluster's own services live under, e.g. coven.omelette.gay. Mail is sent from it"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z]+$", var.cluster_domain))
    error_message = "cluster_domain must be a domain name, e.g. coven.omelette.gay."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificates of the services installed here (Grafana, Vault and Keycloak). On the testlab this is the Vault issuer, which platform creates, so these certificates are only issued once platform has been applied"
  type        = string
  validation {
    condition     = contains(["letsencrypt", "vault"], var.cluster_issuer)
    error_message = "cluster_issuer must be letsencrypt or vault."
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

variable "grafana_host" {
  description = "Hostname for Grafana"
  type        = string
}

variable "vault_host" {
  description = "Hostname for Vault"
  type        = string
}

variable "keycloak_host" {
  description = "Hostname for Keycloak, which serves it under /auth"
  type        = string
}

variable "keycloak_realm" {
  description = "Keycloak realm Grafana logs people in with. The platform stack makes it"
  type        = string
}

variable "smtp_relay" {
  description = "host:port of the SMTP relay that Grafana and Alertmanager send mail through. The platform stack installs it"
  type        = string
}

variable "insecure_tls" {
  description = "Whether Grafana should skip checking Keycloak's certificate, as on the testlab, where it comes from Vault's CA"
  type        = bool
  default     = false
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
  description = "Only set this on the first apply of a fresh cluster: see the keycloak module's bootstrap_admin_password"
  type        = string
  default     = null
  sensitive   = true
}
