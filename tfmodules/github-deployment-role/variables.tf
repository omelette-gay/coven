variable "github_repo" {
  description = "GitHub repo that's allowed to deploy, as owner/name"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be owner/name."
  }
}

variable "k8s_namespace" {
  description = "Namespace the repo is given full access to"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_namespace)) && length(var.k8s_namespace) <= 63
    error_message = "k8s_namespace must be a DNS label (lowercase letters, digits and hyphens, at most 63 characters)."
  }
}

variable "role_name" {
  description = "Name of the role, which vault-k8s-login-action logs in as with `github-` in front (so `weight-tracker` is `github-weight-tracker`)"
  type        = string
}
