terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
  }
}

resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = var.namespace
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = var.namespace
    }
  }
}

# The host packages Longhorn needs (iSCSI) are installed by Ansible. The backup target's credentials and the recurring
# backup and snapshot jobs are made by platform, as the credentials come from Vault and the jobs are Longhorn custom
# resources.
resource "helm_release" "longhorn" {
  name       = "longhorn"
  namespace  = kubernetes_namespace_v1.longhorn.metadata[0].name
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "1.13.0"
  atomic     = true
  wait       = true
  timeout    = 900

  values = [yamlencode({
    defaultSettings = {
      concurrentAutomaticEngineUpgradePerNodeLimit = "3"
      storageOverProvisioningPercentage            = var.over_provisioning_percentage
      # network connections in our cluster are over the internet, so can be slower, so increase the timeout from default
      engineReplicaTimeout = 30
      nodeDrainPolicy      = "allow-if-replica-is-stopped"
      defaultDataLocality  = "best-effort"
      # Fast replica rebuild can only skip data in snapshots that have a checksum, so hash new snapshots straight away
      # rather than waiting for the integrity check cron job. This keeps rebuilds after a reboot small, as most data
      # crosses the WireGuard tunnel.
      snapshotDataIntegrity                                    = "fast-check"
      snapshotDataIntegrityImmediateCheckAfterSnapshotCreation = true
      fastReplicaRebuildEnabled                                = true
    }
    defaultBackupStore = {
      backupTarget                 = "s3://coven-backups@europe-west2/"
      backupTargetCredentialSecret = "gcp-backup-creds"
      pollInterval                 = 180
    }
    persistence = {
      defaultClassReplicaCount                    = 2
      defaultDataLocality                         = "best-effort"
      allowVolumeCreationWithDegradedAvailability = var.allow_degraded_volumes
    }
    metrics = {
      serviceMonitor = { enabled = true }
    }
    networkPolicies = {
      metricsScrapeSources = [{
        namespaceSelector = { matchLabels = { "kubernetes.io/metadata.name" = var.monitoring_namespace } }
        podSelector       = { matchLabels = { prometheus = "kube-prometheus-kube-prome-prometheus" } }
      }]
    }
  })]
}

# k3s's own local-path storage class is the default until this marks it otherwise, leaving Longhorn's as the default.
# k3s puts the annotation back when it restarts, and the next plan sets it again.
resource "kubernetes_annotations" "local_path_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "local-path"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

  depends_on = [helm_release.longhorn]
}
