variable "server_id" {
  description = "Unique identifier for the Minecraft server on the cluster"
  type        = string
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
}

variable "disk_size" {
  description = "How big a disk to assign to the Minecraft data dir"
  type        = string
  default     = "1G"
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
}

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job name to label the backup PVC with. If null, no Longhorn labels are set."
  type        = string
  default     = null
}

variable "prefer_nodes" {
  description = "a node label to prefer running the server on"
  type        = string
  default     = null
}
