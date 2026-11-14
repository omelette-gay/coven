module "weight_tracker_namespace" {
  source = "../../tfmodules/app-namespace"

  name = "weight-tracker"
}

module "weight_tracker_deployment" {
  source = "../../tfmodules/github-deployment-role"

  github_repo   = "cnorthwood/chriss-weight-tracker"
  role_name     = "weight-tracker"
  k8s_namespace = module.weight_tracker_namespace.name
}

module "weight_tracker_google_oauth_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "weight-tracker/google-oauth"
  k8s_secret_name          = "google-oauth"
  k8s_namespace            = module.weight_tracker_namespace.name
  k8s_service_account_name = "weight-tracker-google-oauth-secret"
  vault_role_name          = "weight-tracker-secrets"
}

# The writer service account's key. Being replaced by workload identity federation (see below): remove this, the key and
# the Vault secret once the app uses the google-credentials ConfigMap.
module "weight_tracker_google_service_account_secret" {
  source = "../../tfmodules/vault-k8s-secret"

  vault_secret_name        = "weight-tracker/google-service-account"
  k8s_secret_name          = "google-service-account"
  k8s_namespace            = module.weight_tracker_namespace.name
  k8s_service_account_name = "weight-tracker"
  vault_role_name          = "weight-tracker-google-secret"
}

# The weight tracker's GCP project, "Chris's weight tracker". CI gets access to it in the bootstrap stack. Not managed
# here, because there's no API for them:
# - the project's owners
# - the OAuth consent screen and the OAuth client (in Google Auth Platform), whose ID and secret are put in Vault by
#   hand at secret/weight-tracker/google-oauth. The app uses it to read each user's weight from Google Health.
# - sharing each user's spreadsheet with the writer service account, in Google Drive
locals {
  weight_tracker_gcp_project = "chriss-weight-tracker"
}

# APIs the project was already using, such as BigQuery and Cloud Storage, are left as Google enabled them
resource "google_project_service" "weight_tracker" {
  for_each = toset([
    "health.googleapis.com",         # read users' weight
    "sheets.googleapis.com",         # write the spreadsheet
    "iamcredentials.googleapis.com", # act as the writer service account from the cluster
  ])

  project            = local.weight_tracker_gcp_project
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "weight_tracker_writer" {
  project      = local.weight_tracker_gcp_project
  account_id   = "weight-tracker-writer"
  display_name = "Weight tracker writer"
}

# Lets the app act as the writer service account without a key
module "weight_tracker_writer_identity" {
  source = "../../tfmodules/gcp-workload-identity"

  workload_identity_provider   = local.coven_workload_identity_provider
  google_service_account_name  = google_service_account.weight_tracker_writer.name
  google_service_account_email = google_service_account.weight_tracker_writer.email
  k8s_namespace                = module.weight_tracker_namespace.name
  k8s_service_account_name     = "sheet-writer"
}

import {
  to = google_service_account.weight_tracker_writer
  id = "projects/chriss-weight-tracker/serviceAccounts/weight-tracker-writer@chriss-weight-tracker.iam.gserviceaccount.com"
}
