resource "google_storage_bucket" "backup_bucket" {
  name          = "coven-backups"
  location      = "EUROPE-WEST2"
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
