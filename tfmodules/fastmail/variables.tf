variable "zone" {
  description = "The Hetzner DNS zone to delegate to Fastmail"
  type = object({
    id   = string
    name = string
  })
}
