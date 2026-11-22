variable "namespace" {
  description = "Namespace to install postfix into. This module creates it"
  type        = string
  default     = "mail"
}

variable "domain" {
  description = "Domain mail is sent from, which postfix signs with DKIM"
  type        = string
}

variable "dns_zone" {
  description = "Hetzner DNS zone containing domain, to publish its DKIM, SPF and DMARC records in. Null if there's no public DNS, as on the testlab"
  type = object({
    id   = string
    name = string
  })
  default = null
  validation {
    condition     = var.dns_zone == null || endswith(var.domain, var.dns_zone.name)
    error_message = "domain must be in dns_zone."
  }
}

variable "ipv4_addresses" {
  description = "Addresses mail is sent from, for the SPF record"
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for address in var.ipv4_addresses : can(cidrhost("${address}/32", 0))])
    error_message = "ipv4_addresses must all be IPv4 addresses."
  }
}

variable "node_selector" {
  description = "Node labels postfix must run on, so it sends from an address in the SPF record"
  type        = map(string)
  default     = {}
}

variable "dkim_key_revision" {
  description = "Increase this to generate a new DKIM key. Mail may fail DKIM checks until postfix restarts with the new key"
  type        = number
  default     = 1
  validation {
    condition     = var.dkim_key_revision >= 1 && floor(var.dkim_key_revision) == var.dkim_key_revision
    error_message = "dkim_key_revision must be a whole number, 1 or more."
  }
}

variable "vault_kv_mountpoint" {
  description = "Vault KV v2 mount for the DKIM key. Pass the mount's path from the stack that makes it, so the key is written after it"
  type        = string
  default     = "secret"
}

variable "vault_kubernetes_auth_backend" {
  description = "Path of Vault's Kubernetes auth method. Pass the auth backend's path from the stack that makes it"
  type        = string
  default     = "kubernetes"
}
