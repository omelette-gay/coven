locals {
  endpoint = "http://${var.name}-rustfs-svc.${var.namespace}.svc.cluster.local:9000"

  # renovate: datasource=docker depName=rustfs/rc
  rc_image_tag = "v0.1.37"
}
