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
