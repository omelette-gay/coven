# Longhorn is installed by bootstrap. Its backups go to GCS with an HMAC key that coven's platform stack writes to Vault.
module "longhorn_backup_credentials" {
  source = "../vault-k8s-secret"

  vault_secret_name        = "backups/service-account-creds"
  k8s_secret_name          = "gcp-backup-creds"
  k8s_namespace            = "longhorn-system"
  k8s_service_account_name = "longhorn-gcp-backup-creds"
  vault_role_name          = "longhorn-gcp-backup-creds"
}

# Backs up volumes labelled for it (see backup_labels in bootstrap) off-site
resource "kubernetes_manifest" "longhorn_backup_job" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "nightly-backup"
      namespace = "longhorn-system"
    }
    spec = {
      cron        = "30 7,19 * * *"
      task        = "backup"
      retain      = 14
      concurrency = 2
    }
  }
}

# Replica rebuilds (e.g. after a node reboot) copy everything written since the volume's last snapshot, so volumes that
# are never snapshotted get copied in full over the WireGuard tunnel. The "default" group applies this job to every
# volume that has no recurring job of its own; volumes labelled for the backup job above already get a snapshot with
# each backup. Only a couple are kept, as on volumes with a lot of churn (e.g. RustFS for Loki) each snapshot holds on
# to data that has since been deleted.
resource "kubernetes_manifest" "longhorn_snapshot_job" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "daily-snapshot"
      namespace = "longhorn-system"
    }
    spec = {
      cron        = "0 3 * * *"
      task        = "snapshot"
      groups      = ["default"]
      retain      = 2
      concurrency = 2
    }
  }
}
