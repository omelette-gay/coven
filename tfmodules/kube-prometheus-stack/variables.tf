variable "namespace" {
  description = "Namespace to install into. It must already exist"
  type        = string
}

variable "cluster_domain" {
  description = "Domain the cluster's own services live under, which Grafana and Alertmanager send mail from"
  type        = string
}

variable "grafana_host" {
  description = "Hostname for Grafana"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for Grafana's TLS certificate"
  type        = string
}

variable "keycloak_realm_url" {
  description = "URL of the Keycloak realm Grafana logs people in with, e.g. https://auth.coven.omelette.gay/auth/realms/omelette.gay. Grafana's client and its Secret, grafana-keycloak-creds, are made by the platform stack; until then SSO doesn't work, but Grafana still starts"
  type        = string
  validation {
    condition     = startswith(var.keycloak_realm_url, "https://") && !endswith(var.keycloak_realm_url, "/")
    error_message = "keycloak_realm_url must start with https:// and have no trailing slash."
  }
}

variable "insecure_tls" {
  description = "Whether Grafana should skip checking Keycloak's certificate, as on the testlab, where it comes from Vault's CA"
  type        = bool
  default     = false
}

variable "smtp_relay" {
  description = "host:port of the SMTP relay Grafana and Alertmanager send mail through"
  type        = string
}

variable "host_aliases" {
  description = "Extra /etc/hosts entries for Grafana, e.g. so it can reach Keycloak on the testlab"
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default = []
}

variable "controller_ips" {
  description = "Addresses of the controller nodes, where Prometheus scrapes the k3s components that don't run as pods"
  type        = list(string)
  validation {
    condition     = length(var.controller_ips) > 0 && alltrue([for ip in var.controller_ips : can(cidrhost("${ip}/32", 0)) || can(cidrhost("${ip}/128", 0))])
    error_message = "controller_ips must contain at least one IP address."
  }
}
