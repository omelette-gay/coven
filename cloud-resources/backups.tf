resource "google_storage_bucket" "backup_bucket" {
  name          = "coven-backups"
  location      = "EUROPE-WEST2"
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_service_account" "backup_service_account" {
  account_id  = "coven-backup"
  description = "Service account for coven k8s cluster backups"
}

resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.backup_service_account.member
}

resource "google_storage_hmac_key" "backup_service_account_key" {
  service_account_email = google_service_account.backup_service_account.email
}

resource "vault_kv_secret_v2" "backup_service_account_creds" {
  mount = "secret"
  name  = "backups/service-account-creds"
  data_json = jsonencode(
    {
      AWS_ACCESS_KEY_ID     = google_storage_hmac_key.backup_service_account_key.access_id
      AWS_ENDPOINTS         = "https://storage.googleapis.com"
      AWS_SECRET_ACCESS_KEY = google_storage_hmac_key.backup_service_account_key.secret
    }
  )
}
