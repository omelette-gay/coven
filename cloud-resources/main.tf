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
  project = "coven-omelette-gay"
  region  = "europe-west2"
  user_project_override = true
  billing_project = "coven-omelette-gay"
}

provider "vault" {
  address = "https://vault.coven.omelette.gay"
}
