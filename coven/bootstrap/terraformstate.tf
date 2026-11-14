resource "google_storage_bucket" "tfstate_bucket" {
  name     = "coven-tfstate"
  location = "EUROPE-WEST2"

  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Every apply writes a new version of a stack's state, and state holds secrets (see docs/secrets.md), so old versions
  # are deleted after 30 days. The current version is never deleted. That's long enough to roll back from a bad apply or
  # a corrupted state, and bounds how long a rotated secret stays in the bucket's history.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
