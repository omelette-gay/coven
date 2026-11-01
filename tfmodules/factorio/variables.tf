variable "server_id" {
  description = "Unique identifier for the Factorio server on the cluster"
  type        = string
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

variable "longhorn_recurring_job_name" {
  description = "Longhorn recurring job name to label the data PVC with. If null, no Longhorn labels are set."
  type        = string
  default     = null
}
