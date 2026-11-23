# The cluster's workload identity pool moved to the bootstrap stack (ADR 006), so CI can't change it. Forget it here
# without deleting it. These, and the external provider in main.tf, can go once platform's state no longer has them.

removed {
  from = google_iam_workload_identity_pool.coven

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_iam_workload_identity_pool_provider.coven

  lifecycle {
    destroy = false
  }
}
