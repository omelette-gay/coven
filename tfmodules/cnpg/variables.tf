variable "namespace" {
  description = "Namespace to install the CloudNativePG operator into. This module creates it"
  type        = string
  default     = "cnpg-system"
}
