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
