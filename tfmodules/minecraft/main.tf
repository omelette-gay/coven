terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.68.0"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "minecraft-${var.server_id}"
  }
}

resource "helm_release" "minecraft" {
  name       = var.server_id
  namespace  = resource.kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://itzg.github.io/minecraft-server-charts/"
  chart      = "minecraft"
  version    = "5.1.3"
  values = [
    yamlencode({
      minecraftServer = {
        eula       = true
        difficulty = "normal"
        type       = "PAPER"
        whitelist  = join(",", var.whitelist)
        ops        = join(",", var.ops)
        motd       = var.motd

        serviceType = "LoadBalancer"
        servicePort = var.port

        memory = var.memory
        tty    = false
      }
      extraEnv = {
        USE_MEOWICE_FLAGS = "true"
      }
      persistence = {
        dataDir = {
          enabled = true
        }
      }
      serviceAnnotations = var.dns == null ? {} : {
        "external-dns.alpha.kubernetes.io/hostname" = "minecraft-svc.${var.dns.hostname}"
      }
    })
  ]
}

resource "hcloud_zone_rrset" "srv" {
  count = var.dns == null ? 0 : 1

  name = trimsuffix("_minecraft._tcp.${trimsuffix(var.dns.hostname, var.dns.zone.name)}", ".")
  type = "SRV"
  zone = var.dns.zone.id
  records = [
    {
      value = "0 0 ${var.port} minecraft-svc.${var.dns.hostname}."
    }
  ]
}
