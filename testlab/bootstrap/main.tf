terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
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
