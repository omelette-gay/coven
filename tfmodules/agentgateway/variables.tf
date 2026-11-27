variable "name" {
  description = "Name of the Helm release, Service and ingress, and of the upstream in agentgateway's logs and metrics"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 53
    error_message = "name must be a DNS label of at most 53 characters, as Helm release names are."
  }
}

variable "namespace" {
  description = "Namespace to install the gateway into. It must already exist, and hold tls_secret_name"
  type        = string
}

variable "host" {
  description = "Public hostname MCP clients connect to"
  type        = string
  validation {
    condition     = can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.host))
    error_message = "host must be a bare hostname, without https:// or a trailing slash."
  }
}

variable "path" {
  description = "Path of the MCP endpoint on host. The gateway serves it, and its protected resource metadata at /.well-known/oauth-protected-resource<path>"
  type        = string
  validation {
    condition     = startswith(var.path, "/") && !endswith(var.path, "/")
    error_message = "path must start with a slash and not end with one, e.g. /api/v2/mcp."
  }
}

variable "tls_secret_name" {
  description = "Existing TLS Secret in namespace with a certificate for host, e.g. the one the upstream's own ingress uses. The gateway doesn't request a certificate of its own"
  type        = string
}

variable "upstream_url" {
  description = "In-cluster URL of the upstream MCP server (streamable HTTP)"
  type        = string
}

variable "oidc_issuer" {
  description = "OIDC issuer that access tokens must come from, matched exactly against their iss claim, e.g. https://auth.coven.omelette.gay/auth/realms/omelette.gay. MCP clients are sent here to log in"
  type        = string
  validation {
    condition     = startswith(var.oidc_issuer, "https://") && !endswith(var.oidc_issuer, "/")
    error_message = "oidc_issuer must start with https:// and have no trailing slash."
  }
}

variable "oidc_jwks_url" {
  description = "URL of the issuer's signing keys. It can be an in-cluster address, as it's only fetched by the gateway"
  type        = string
}

variable "credential_claim" {
  description = "Access token claim holding the caller's credential for the upstream. It's sent upstream as a bearer token in place of the access token, and requests without it are refused"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.credential_claim))
    error_message = "credential_claim must be a plain identifier (letters, digits and underscores), as it's used in a CEL expression."
  }
}

variable "scopes_supported" {
  description = "Scopes advertised in the protected resource metadata, which MCP clients ask for when they log in"
  type        = list(string)
  default     = ["openid", "offline_access"]
}
