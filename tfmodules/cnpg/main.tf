terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "cnpg" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

# The CloudNativePG operator, which runs every PostgreSQL cluster (each app installs its own with the `cluster` chart)
resource "helm_release" "cnpg" {
  name       = "cnpg"
  namespace  = kubernetes_namespace_v1.cnpg.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.29.2"
  atomic     = true
  wait       = true

  values = [yamlencode({
    monitoring = {
      podMonitorEnabled = true
      grafanaDashboard  = { create = true }
    }
    config = {
      data = {
        # A catalog update changes the image of every cluster on the same major. Space the rolling updates out, so
        # they don't all restart and switch over at once
        CLUSTERS_ROLLOUT_DELAY  = tostring(var.clusters_rollout_delay)
        INSTANCES_ROLLOUT_DELAY = tostring(var.instances_rollout_delay)
      }
    }
  })]
}

locals {
  # The upstream catalog of minimal Debian trixie images, at a pinned commit. Renovate updates the commit (weekly, with
  # the Platform bundle), so every image change is a reviewed pull request.
  # renovate: datasource=git-refs depName=https://github.com/cloudnative-pg/artifacts
  image_catalog_commit = "main@bfb9f410a35f64c831c06f886078a30b202b0304"
  image_catalog_url    = "https://raw.githubusercontent.com/cloudnative-pg/artifacts/${split("@", local.image_catalog_commit)[1]}/image-catalogs/catalog-minimal-trixie.yaml"
  image_catalog        = yamldecode(data.http.image_catalog.response_body)
}

data "http" "image_catalog" {
  url = local.image_catalog_url

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Couldn't fetch the PostgreSQL image catalog from ${local.image_catalog_url}: HTTP ${self.status_code}."
    }
  }
}

# The ClusterImageCatalog every PostgreSQL cluster takes its image from, by referencing it with
# `cluster.imageCatalogRef` and setting only its major version. When an image changes, the operator rolls every cluster
# on that major. Its CRD comes from the operator above, so it's made through a small local chart rather than
# kubernetes_manifest (see ADR 002 and ADR 009)
resource "helm_release" "image_catalog" {
  name      = "image-catalog"
  namespace = kubernetes_namespace_v1.cnpg.metadata[0].name
  chart     = "${path.module}/charts/image-catalog"
  atomic    = true
  wait      = true

  values = [yamlencode({
    name   = var.image_catalog_name
    labels = local.image_catalog.metadata.labels
    images = local.image_catalog.spec.images
  })]

  lifecycle {
    precondition {
      condition     = local.image_catalog.kind == "ClusterImageCatalog"
      error_message = "${local.image_catalog_url} isn't a ClusterImageCatalog."
    }
  }

  depends_on = [helm_release.cnpg]
}

# Lets the PostgreSQL clusters back up to GCS (see docs/backups-and-recovery.md)
resource "helm_release" "plugin_barman_cloud" {
  name       = "plugin-barman-cloud"
  namespace  = kubernetes_namespace_v1.cnpg.metadata[0].name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "plugin-barman-cloud"
  version    = "0.9.0"
  atomic     = true
  wait       = true

  depends_on = [helm_release.cnpg]
}
