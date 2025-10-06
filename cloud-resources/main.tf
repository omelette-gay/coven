variable "project_id" {
  description = "The project ID"
  type        = string
  default     = "coven-omelette-gay"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.2.1"
    }
  }
}

provider "google" {
  project               = var.project_id
  region                = "europe-west2"
  user_project_override = true
  billing_project       = var.project_id
}

provider "vault" {
  address = "https://vault.coven.omelette.gay"
}
