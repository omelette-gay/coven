variable "namespace" {
  description = "Namespace of the service whose paths are blocked"
  type        = string
}

variable "name" {
  description = "Name of the IngressRoute and Middleware"
  type        = string
  default     = "block-metrics-path"
}

variable "host" {
  description = "Hostname the service is exposed on"
  type        = string
}

variable "path_regexp" {
  description = "Go regular expression matched against the request path, e.g. ^/metrics"
  type        = string
  validation {
    condition     = startswith(var.path_regexp, "^/") && !strcontains(var.path_regexp, "`")
    error_message = "path_regexp must be anchored to the start of the path (begin with ^/) and contain no backticks."
  }
}

variable "tls_secret_name" {
  description = "Secret holding the TLS certificate for host, usually the one cert-manager creates for the service's own Ingress"
  type        = string
}
