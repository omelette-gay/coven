resource "google_storage_bucket" "backup_bucket" {
  name          = "coven-backups"
  location      = "EUROPE-WEST2"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # k3s datastore snapshots are taken every few hours by the omelette.k3s-backup Ansible role, which doesn't clean up
  # after itself, so expire them here. matches_prefix only matches from the start of the object name, so this can't
  # touch the cnpg/, mariadb/ or Longhorn backups, which manage their own retention.
  lifecycle_rule {
    condition {
      age            = 14
      matches_prefix = ["k3s/"]
    }
    action {
      type = "Delete"
    }
  }
}

# the service account's keys, and writing them into Vault, are in the platform stack
resource "google_service_account" "backup_service_account" {
  account_id  = "coven-backup"
  description = "Service account for coven k8s cluster backups"
}

resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.backup_service_account.member
}
