variable "keycloak_url" {
  description = "Keycloak base URL, including the base path"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer used for TLS certificates"
  type        = string
}

variable "cluster_domain" {
  description = "Domain the cluster's own services live under, e.g. coven.omelette.gay. Also the domain outbound mail is sent from"
  type        = string
}

variable "kubernetes_api_url" {
  description = "Address Vault uses to reach the Kubernetes API, to check service account tokens and to issue credentials"
  type        = string
}

variable "insecure_tls" {
  description = "Whether Vault should trust Keycloak's certificate on the testlab, where it comes from Vault's own CA rather than Let's Encrypt"
  type        = bool
  default     = false
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

variable "grafana_keycloak_secret_revision" {
  description = "Increase this to rotate Grafana's Keycloak client secret. Grafana reads it when it starts, so restart it afterwards"
  type        = number
  default     = 1
}

variable "vault_keycloak_secret_revision" {
  description = "Increase this to rotate the client secret Vault uses to log people in through Keycloak. Terraform writes it to Keycloak and Vault together"
  type        = number
  default     = 1
}

variable "discord_alerts" {
  description = "Whether to send Grafana and Alertmanager alerts to Discord, using the webhook URL in Vault at gitops/grafana-discord-notifier"
  type        = bool
  default     = false
}

variable "loki_storage_size" {
  description = "Size of the volume Loki keeps its logs on"
  type        = string
  default     = "5Gi"
}

variable "loki_chunks_cache_memory" {
  description = "Memory for Loki's chunks cache, in MB"
  type        = number
  default     = 4096
}

variable "dns" {
  description = "Whether to manage public DNS: external-dns, the records for outbound mail, and extra_records. Off on the testlab, which has no public DNS"
  type = object({
    enabled = bool
    # Records external-dns doesn't make, in the omelette.gay zone
    extra_records = optional(map(object({
      name   = string
      type   = string
      values = list(string)
    })), {})
    # Addresses outbound mail is sent from, for the SPF record
    mail_ipv4_addresses = optional(list(string), [])
  })
  default = {
    enabled = false
  }
}

variable "outbound_mail_node_selector" {
  description = "Node labels outbound mail must run on, so it sends from an address in its SPF record"
  type        = map(string)
  default     = {}
}

variable "dkim_key_revision" {
  description = "Increase this to generate a new DKIM key for outbound mail. Mail may fail DKIM checks until postfix restarts with the new key"
  type        = number
  default     = 1
}
