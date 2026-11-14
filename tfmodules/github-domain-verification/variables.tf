variable "zone" {
  description = "The Hetzner DNS zone to verify with GitHub"
  type = object({
    id   = string
    name = string
  })
}

variable "organisation" {
  description = "The GitHub organisation the domain is being verified for"
  type        = string
}

variable "verification_code" {
  description = "The code GitHub gives when adding the domain under the organisation's Verified and approved domains settings"
  type        = string
}

variable "pages_verification_code" {
  description = "The code GitHub gives when adding the domain under the organisation's Pages settings. Leave unset to skip the Pages record"
  type        = string
  default     = null
}
