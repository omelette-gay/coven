terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "local"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "local"
}

provider "hcloud" {
  token = "0000000000000000000000000000000000000000000000000000000000000000"
}

module "bootstrap" {
  source = "../../tfmodules/stack-bootstrap"
}
