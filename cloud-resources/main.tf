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
}

provider "vault" {
  address = "https://vault.coven.omelette.gay"
}
