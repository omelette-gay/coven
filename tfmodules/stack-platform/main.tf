terraform {
  required_version = ">= 1.11.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.10.1"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 5.9.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.68.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1.0"
    }
  }
}

locals {
  grafana_host = "monitoring.${var.cluster_domain}"
  vault_host   = "vault.${var.cluster_domain}"

  smtp_host = "mail.mail.svc.cluster.local"
  smtp_port = "587"

  # the blackbox exporter installed by bootstrap, which probes our sites from inside the cluster
  blackbox_prober = {
    url  = "blackbox-exporter-prometheus-blackbox-exporter.monitoring.svc.cluster.local:9115"
    path = "/probe"
  }

  # the omelette.gay zone, made by coven's bootstrap stack
  omelette_gay_zone_id = "798597"
}
