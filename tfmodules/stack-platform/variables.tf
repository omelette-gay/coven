variable "cluster_domain" {
  description = "Domain the cluster's own services live under, e.g. coven.omelette.gay. Outbound mail is sent from it, and external-dns marks the records it manages with it"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z]+$", var.cluster_domain))
    error_message = "cluster_domain must be a domain name, e.g. coven.omelette.gay."
  }
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for the TLS certificates of the services installed here"
  type        = string
  validation {
    condition     = contains(["letsencrypt", "vault"], var.cluster_issuer)
    error_message = "cluster_issuer must be letsencrypt or vault."
  }
}

variable "keycloak_url" {
  description = "Keycloak base URL, including the base path, e.g. https://auth.coven.omelette.gay/auth"
  type        = string
  validation {
    condition     = startswith(var.keycloak_url, "https://") && !endswith(var.keycloak_url, "/")
    error_message = "keycloak_url must start with https:// and have no trailing slash."
  }
}

variable "keycloak_realm" {
  description = "Name of the Keycloak realm everyone logs in to apps with, which this stack makes"
  type        = string
}

variable "namespaces" {
  description = "Namespaces of the services the bootstrap stack installs"
  type = object({
    monitoring   = string
    longhorn     = string
    cert_manager = string
    vault        = string
    keycloak     = string
  })
}

variable "grafana_host" {
  description = "Hostname of Grafana, which the bootstrap stack installs"
  type        = string
}

variable "vault_host" {
  description = "Hostname of Vault, which the bootstrap stack installs"
  type        = string
}

variable "kubernetes_api_url" {
  description = "Address Vault uses to reach the Kubernetes API, to check service account tokens and to issue credentials"
  type        = string
  validation {
    condition     = startswith(var.kubernetes_api_url, "https://")
    error_message = "kubernetes_api_url must start with https://."
  }
}

variable "insecure_tls" {
  description = "Whether Vault should trust Keycloak's certificate on the testlab, where it comes from Vault's own CA rather than Let's Encrypt"
  type        = bool
  default     = false
}

variable "glitchtip_host" {
  description = "Hostname for GlitchTip"
  type        = string
}

variable "glitchtip_postgresql_instances" {
  description = "Number of CNPG PostgreSQL instances for GlitchTip"
  type        = number
  validation {
    condition     = var.glitchtip_postgresql_instances >= 1 && floor(var.glitchtip_postgresql_instances) == var.glitchtip_postgresql_instances
    error_message = "glitchtip_postgresql_instances must be a whole number, 1 or more."
  }
}

variable "glitchtip_sender_email" {
  description = "Email address GlitchTip sends emails from"
  type        = string
}

variable "glitchtip_keycloak_secret_revision" {
  description = "Increase this to rotate GlitchTip's Keycloak client secret (see the glitchtip module)"
  type        = number
  default     = 1
  validation {
    condition     = var.glitchtip_keycloak_secret_revision >= 1 && floor(var.glitchtip_keycloak_secret_revision) == var.glitchtip_keycloak_secret_revision
    error_message = "glitchtip_keycloak_secret_revision must be a whole number, 1 or more."
  }
}

variable "grafana_keycloak_secret_revision" {
  description = "Increase this to rotate Grafana's Keycloak client secret. Grafana is restarted to read the new one"
  type        = number
  default     = 1
  validation {
    condition     = var.grafana_keycloak_secret_revision >= 1 && floor(var.grafana_keycloak_secret_revision) == var.grafana_keycloak_secret_revision
    error_message = "grafana_keycloak_secret_revision must be a whole number, 1 or more."
  }
}

variable "vault_keycloak_secret_revision" {
  description = "Increase this to rotate the client secret Vault uses to log people in through Keycloak. Terraform writes it to Keycloak and Vault together"
  type        = number
  default     = 1
  validation {
    condition     = var.vault_keycloak_secret_revision >= 1 && floor(var.vault_keycloak_secret_revision) == var.vault_keycloak_secret_revision
    error_message = "vault_keycloak_secret_revision must be a whole number, 1 or more."
  }
}

variable "keycloak_automation_password_revision" {
  description = "Increase this to give Terraform's own Keycloak user a new password, written to Keycloak and Vault together"
  type        = number
  default     = 1
  validation {
    condition     = var.keycloak_automation_password_revision >= 1 && floor(var.keycloak_automation_password_revision) == var.keycloak_automation_password_revision
    error_message = "keycloak_automation_password_revision must be a whole number, 1 or more."
  }
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

variable "dns_zone" {
  description = "Hetzner DNS zone containing cluster_domain, where external-dns manages records and outbound mail's DKIM, SPF and DMARC records are published. Null if there's no public DNS, as on the testlab"
  type = object({
    id   = string
    name = string
  })
  default = null
}

variable "mail_ipv4_addresses" {
  description = "Addresses outbound mail is sent from, for the SPF record"
  type        = list(string)
  default     = []
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
  validation {
    condition     = var.dkim_key_revision >= 1 && floor(var.dkim_key_revision) == var.dkim_key_revision
    error_message = "dkim_key_revision must be a whole number, 1 or more."
  }
}

variable "backup_bucket" {
  description = "GCS bucket Keycloak's database and Longhorn back up to, or null for no backups (as on the testlab). With none, the backup credentials aren't synced and there's no backup job"
  type        = string
  default     = null
}

variable "longhorn_backup_job_name" {
  description = "Name of the Longhorn recurring job that backs labelled volumes up off-site. The bootstrap stack labels Vault's volume for it"
  type        = string
}

variable "longhorn_backup_credentials_secret" {
  description = "Secret to sync Longhorn's GCS backup credentials into. The bootstrap stack points Longhorn at it"
  type        = string
}

variable "keycloak_backup_credentials_secret" {
  description = "Secret to sync the GCP service account key Keycloak's database backs up with into. The bootstrap stack points the database at it"
  type        = string
}

variable "grafana_oauth_secret" {
  description = "Secret to write Grafana's Keycloak client into. The bootstrap stack points Grafana at it"
  type        = string
}

variable "postgresql_image_catalog" {
  description = "Name of the ClusterImageCatalog PostgreSQL clusters take their image from, which the bootstrap stack makes (see ADR 009)"
  type        = string
}
