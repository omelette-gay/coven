terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

# The services here are modules, ordered with depends_on where one needs another installed first. ADR 002 warns against
# depends_on on modules because it delays the module's data sources until apply, but none of these modules has any (the
# one data source this stack needs, the controller nodes, is in monitoring.tf), so it's safe here. Keep it that way.

locals {
  # Longhorn volumes with these labels are backed up off-site by the recurring job the platform stack creates
  longhorn_backup_labels = {
    "recurring-job.longhorn.io/source"                          = "enabled"
    "recurring-job.longhorn.io/${var.longhorn_backup_job_name}" = "enabled"
  }
}
