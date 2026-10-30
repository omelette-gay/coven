# Resources moved out of the coven/ root module (ADR 002). Delete this file once it's been applied.

import {
  to = google_project_service.iam
  id = "coven-omelette-gay/iam.googleapis.com"
}

import {
  to = google_project_service.cloudresourcemanager
  id = "coven-omelette-gay/cloudresourcemanager.googleapis.com"
}

import {
  to = google_project_service.iamcredentials
  id = "coven-omelette-gay/iamcredentials.googleapis.com"
}

import {
  to = google_project_service.sts
  id = "coven-omelette-gay/sts.googleapis.com"
}

import {
  to = google_project_service.billing
  id = "coven-omelette-gay/cloudbilling.googleapis.com"
}

import {
  to = google_project_service.billingbudgets
  id = "coven-omelette-gay/billingbudgets.googleapis.com"
}

import {
  to = google_project_service.secretmanager
  id = "coven-omelette-gay/secretmanager.googleapis.com"
}

import {
  to = google_storage_bucket.tfstate_bucket
  id = "coven-tfstate"
}

import {
  to = google_monitoring_notification_channel.budget_notification_channel_1
  id = "projects/coven-omelette-gay/notificationChannels/11267148600497170489"
}

import {
  to = google_monitoring_notification_channel.budget_notification_channel_2
  id = "projects/coven-omelette-gay/notificationChannels/14660397672885832752"
}

import {
  to = google_billing_budget.warningbudget
  id = "billingAccounts/01D108-8BDE28-8F3D32/budgets/31bf428b-e08a-4d20-934a-555c66ecab13"
}

import {
  to = google_secret_manager_secret.k3s_token
  id = "projects/coven-omelette-gay/secrets/k3s-cluster-token"
}

import {
  to = google_iam_workload_identity_pool.omelette_gay_github_actions
  id = "projects/coven-omelette-gay/locations/global/workloadIdentityPools/omelette-gay-github-actions"
}

import {
  to = google_iam_workload_identity_pool_provider.omelette_gay_github_actions
  id = "projects/coven-omelette-gay/locations/global/workloadIdentityPools/omelette-gay-github-actions/providers/omelette-gay-github-actions"
}

import {
  to = google_project_iam_member.gitops_repo_role
  id = "coven-omelette-gay roles/editor principalSet://iam.googleapis.com/projects/211831137824/locations/global/workloadIdentityPools/omelette-gay-github-actions/attribute.repository/omelette-gay/gitops"
}

import {
  to = google_secret_manager_secret_iam_member.gitops_repo_k3s_token_accessor
  id = "projects/coven-omelette-gay/secrets/k3s-cluster-token roles/secretmanager.secretAccessor principalSet://iam.googleapis.com/projects/211831137824/locations/global/workloadIdentityPools/omelette-gay-github-actions/attribute.repository/omelette-gay/gitops"
}

import {
  to = google_storage_bucket.backup_bucket
  id = "coven-backups"
}

import {
  to = google_service_account.backup_service_account
  id = "projects/coven-omelette-gay/serviceAccounts/coven-backup@coven-omelette-gay.iam.gserviceaccount.com"
}

import {
  to = google_storage_bucket_iam_member.backup_writer
  id = "b/coven-backups roles/storage.objectAdmin serviceAccount:coven-backup@coven-omelette-gay.iam.gserviceaccount.com"
}

import {
  to = hcloud_zone.omelette_gay
  id = "omelette.gay"
}
