terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

locals {
  token_path = "/var/run/secrets/google/token"

  # projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>
  pool_name = regex("^(projects/[^/]+/locations/global/workloadIdentityPools/[^/]+)/providers/[^/]+$", var.workload_identity_provider)[0]

  # What Google's client libraries send to STS. Tokens must carry the same with https: in front.
  audience = "//iam.googleapis.com/${var.workload_identity_provider}"
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.k8s_service_account_name
    namespace = var.k8s_namespace
  }

  # The pods mount their own token, with Google's audience
  automount_service_account_token = false
}

resource "google_service_account_iam_member" "this" {
  service_account_id = var.google_service_account_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.pool_name}/subject/system:serviceaccount:${var.k8s_namespace}:${kubernetes_service_account_v1.this.metadata[0].name}"
}

resource "kubernetes_config_map_v1" "this" {
  metadata {
    name      = var.config_map_name
    namespace = var.k8s_namespace
  }

  data = {
    # Not read by the client libraries; for the pods' token volume
    "audience"   = "https:${local.audience}"
    "token_path" = local.token_path

    "credentials.json" = jsonencode({
      type                              = "external_account"
      audience                          = local.audience
      subject_token_type                = "urn:ietf:params:oauth:token-type:jwt"
      token_url                         = "https://sts.googleapis.com/v1/token"
      service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${var.google_service_account_email}:generateAccessToken"
      credential_source = {
        file = local.token_path
      }
    })
  }
}
