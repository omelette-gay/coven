variable "server_id" {
  description = "Unique identifier for the Factorio server on the cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.server_id)) && length(var.server_id) <= 53
    error_message = "server_id must be a DNS label of at most 53 characters (lowercase letters, digits and hyphens), as it's used in namespace and Helm release names."
  }
}

variable "port" {
  description = "UDP port for the Factorio server"
  type        = number
  default     = 31497
}

variable "save_name" {
  description = "Name of the save file the server loads"
  type        = string
}

variable "enable_space_age" {
  description = "Whether to enable the Space Age expansion"
  type        = bool
  default     = true
}

variable "server_name" {
  description = "Name shown in the server browser"
  type        = string
}

variable "description" {
  description = "Description shown in the server browser"
  type        = string
  default     = ""
}

variable "password_protected" {
  description = "Whether the server needs a game password, read from factorio/<server_id> in Vault"
  type        = bool
  default     = false
}

variable "dns" {
  description = "Optional DNS configuration for the Factorio server"
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
  description = "How much memory to request for the server"
  type        = string
  default     = "512Mi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.memory))
    error_message = "memory must be a Kubernetes quantity, e.g. 2Gi."
  }
}

variable "disk_size" {
  description = "How big a disk to assign to the Factorio data dir"
  type        = string
  default     = "1Gi"
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?$", var.disk_size))
    error_message = "disk_size must be a Kubernetes quantity, e.g. 2Gi."
  }
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job name to label the data PVC with. If null, no Longhorn labels are set."
  type        = string
  default     = null
}

variable "preferred_node_labels" {
  description = "Node labels to prefer running the server on, e.g. { \"coven.omelette.gay/location\" = \"xdc\" }"
  type        = map(string)
  default     = {}
}
