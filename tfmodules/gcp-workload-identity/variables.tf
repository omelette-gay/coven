variable "workload_identity_provider" {
  description = "Full name of the cluster's workload identity pool provider (projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>)"
  type        = string
  validation {
    condition     = can(regex("^projects/[0-9]+/locations/global/workloadIdentityPools/[^/]+/providers/[^/]+$", var.workload_identity_provider))
    error_message = "workload_identity_provider must be projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>, with the project number."
  }
}

variable "google_service_account_name" {
  description = "Full name of the GCP service account to act as (projects/<project>/serviceAccounts/<email>), e.g. google_service_account.x.name"
  type        = string
}

variable "google_service_account_email" {
  description = "Email of the GCP service account to act as"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the ServiceAccount and ConfigMap"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_namespace)) && length(var.k8s_namespace) <= 63
    error_message = "k8s_namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "k8s_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount to create, which the pods run as"
  type        = string
}

variable "config_map_name" {
  description = "Name of the ConfigMap holding the credentials file"
  type        = string
  default     = "google-credentials"
}
