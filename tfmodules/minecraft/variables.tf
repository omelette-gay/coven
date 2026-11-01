variable "server_id" {
  description = "Unique identifier for the Minecraft server on the cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.server_id)) && length(var.server_id) <= 53
    error_message = "server_id must be a DNS label of at most 53 characters (lowercase letters, digits and hyphens), as it's used in namespace and Helm release names."
  }
}

variable "whitelist" {
  description = "List of players to whitelist on the Minecraft server"
  type        = list(string)
  default     = []
}

variable "ops" {
  description = "List of players to give operator privileges on the Minecraft server"
  type        = list(string)
  default     = []
}

variable "motd" {
  description = "Message of the day for the Minecraft server"
  type        = string
  default     = "Welcome to the Minecraft server!"
}

variable "port" {
  description = "Port for the Minecraft server"
  type        = number
}

variable "dns" {
  description = "Optional DNS configuration for the Minecraft server"
  type = object({
    hostname = string
    zone = object({
      id   = string
      name = string
    })
  })
  default = null
}

variable "memory" {
  description = "How much memory to assign to the server"
  type        = string
  default     = "1G"
  validation {
    condition     = can(regex("^[0-9]+G$", var.memory))
    error_message = "memory must be a whole number of gigabytes, e.g. 4G, as the container limit is worked out from it."
  }
}

variable "disk_size" {
  description = "How big a disk to assign to the Minecraft data dir"
  type        = string
  default     = "1Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.disk_size))
    error_message = "disk_size must be a Kubernetes quantity, e.g. 2Gi."
  }
}

variable "backups_enabled" {
  description = "Whether to enable periodic world backups"
  type        = bool
  default     = false
}

variable "backup_disk_size" {
  description = "How big a disk to assign to the Minecraft backup dir"
  type        = string
  default     = "5G"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.backup_disk_size))
    error_message = "backup_disk_size must be a Kubernetes quantity, e.g. 2Gi."
  }
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job name to label the backup PVC with. If null, no Longhorn labels are set."
  type        = string
  default     = null
}

variable "preferred_node_labels" {
  description = "Node labels to prefer running the server on, e.g. { \"coven.omelette.gay/location\" = \"xdc\" }"
  type        = map(string)
  default     = {}
}
