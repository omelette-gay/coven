variable "namespace" {
  description = "Namespace to install External Secrets Operator into. This module creates it"
  type        = string
  default     = "external-secrets"
}
