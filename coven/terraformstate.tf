resource "google_storage_bucket" "tfstate_bucket" {
  name     = "coven-tfstate"
  location = "EUROPE-WEST2"

  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
