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

# rotate keys every 30 days
resource "time_rotating" "backup_service_account_key_rotation" {
  rotation_days = 30
}

# you can't trigger a replace by rotation automatically, so this works around it https://github.com/hashicorp/terraform-provider-time/issues/118
resource "time_static" "backup_service_account_key_rotation" {
  rfc3339 = time_rotating.backup_service_account_key_rotation.rfc3339
}

# create HMAC credentials and write to a Vault secret - this is compatible with AWS formats (which Longhorn needs)
resource "google_storage_hmac_key" "backup_service_account_key" {
  service_account_email = google_service_account.backup_service_account.email

  lifecycle {
    replace_triggered_by = [time_static.backup_service_account_key_rotation]
  }
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

# create Google Service Account key credentials and write to a Vault secret - this is used for cnpg backup
resource "google_service_account_key" "backup_service_account_key" {
  service_account_id = google_service_account.backup_service_account.name

  keepers = {
    rotation_time = time_rotating.backup_service_account_key_rotation.rotation_rfc3339
  }
}

resource "vault_kv_secret_v2" "backup_service_account_key" {
  mount = "secret"
  name  = "backups/service-account-key"

  data_json = jsonencode(
    {
      "APPLICATION_CREDENTIALS" = base64decode(google_service_account_key.backup_service_account_key.private_key)
    }
  )
}
