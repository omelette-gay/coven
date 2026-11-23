# Trust tokens for the cluster's Kubernetes service accounts, so pods can act as GCP service accounts without keys. The
# pool only identifies them: each GCP service account says which Kubernetes service accounts can act as it, with the
# gcp-workload-identity module. GCP service accounts in any project can use this pool.
#
# Applied by a project owner from their own machine, like the GitHub Actions pool in githubactions.tf: CI can read the
# pools but not change them (ADR 006). The keys only change when the cluster is rebuilt, and then an owner applies
# bootstrap before CI's next apply, or CI's apply fails.

# Google can't reach the cluster's API server, so give it the cluster's issuer and public signing keys, read from the
# cluster on each plan. They aren't secret.
data "external" "coven_service_account_issuer" {
  program = ["sh", "-c", <<-EOT
    jq -n \
      --argjson config "$(kubectl get --raw /.well-known/openid-configuration)" \
      --argjson jwks "$(kubectl get --raw /openid/v1/jwks)" \
      '{issuer: $config.issuer, jwks: ($jwks | tojson)}'
  EOT
  ]
}

resource "google_iam_workload_identity_pool" "coven" {
  workload_identity_pool_id = "coven"
  display_name              = "coven cluster"
  description               = "Service accounts in the coven k3s cluster"
}

resource "google_iam_workload_identity_pool_provider" "coven" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.coven.workload_identity_pool_id
  workload_identity_pool_provider_id = "coven-k3s"
  display_name                       = "coven k3s"

  attribute_mapping = {
    "google.subject" = "assertion.sub" # system:serviceaccount:<namespace>:<name>
  }

  attribute_condition = "assertion.sub.startsWith('system:serviceaccount:')"

  oidc {
    issuer_uri = data.external.coven_service_account_issuer.result.issuer
    jwks_json  = data.external.coven_service_account_issuer.result.jwks
  }
}
