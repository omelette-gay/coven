variable "namespace" {
  description = "Namespace to install the CloudNativePG operator into. This module creates it"
  type        = string
  default     = "cnpg-system"
}

variable "clusters_rollout_delay" {
  description = "Seconds the operator waits between rolling updates of different PostgreSQL clusters, e.g. after an image catalog update"
  type        = number
  default     = 300

  validation {
    condition     = var.clusters_rollout_delay >= 0 && floor(var.clusters_rollout_delay) == var.clusters_rollout_delay
    error_message = "clusters_rollout_delay must be a whole number of seconds, 0 or more."
  }
}

variable "instances_rollout_delay" {
  description = "Seconds the operator waits between restarting instances of the same PostgreSQL cluster during a rolling update"
  type        = number
  default     = 60

  validation {
    condition     = var.instances_rollout_delay >= 0 && floor(var.instances_rollout_delay) == var.instances_rollout_delay
    error_message = "instances_rollout_delay must be a whole number of seconds, 0 or more."
  }
}

variable "image_catalog_name" {
  description = "Name of the ClusterImageCatalog this module makes, which PostgreSQL clusters reference with cluster.imageCatalogRef (see ADR 007). Self-deploying apps use it too, so changing it means changing every app"
  type        = string
}
