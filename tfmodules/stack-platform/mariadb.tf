# The MariaDB operator, for apps that use MariaDB. Its webhook certificate comes from the Vault ClusterIssuer.
resource "kubernetes_namespace_v1" "mariadb" {
  metadata {
    name = "mariadb-system"
    # added by Helm when it made the namespace, kept so the import doesn't change it
    labels = {
      name = "mariadb-system"
    }
  }
}

resource "helm_release" "mariadb_operator_crds" {
  name       = "mariadb-operator-crds"
  namespace  = kubernetes_namespace_v1.mariadb.metadata[0].name
  repository = "https://helm.mariadb.com/mariadb-operator"
  chart      = "mariadb-operator-crds"
  version    = "26.10.2"
  atomic     = true
  wait       = true
}

resource "helm_release" "mariadb_operator" {
  name       = "mariadb-operator"
  namespace  = kubernetes_namespace_v1.mariadb.metadata[0].name
  repository = "https://helm.mariadb.com/mariadb-operator"
  chart      = "mariadb-operator"
  version    = "26.10.2"
  atomic     = true
  wait       = true

  values = [yamlencode({
    metrics = { enabled = true }
    webhook = {
      cert = {
        certManager = {
          enabled = true
          issuerRef = {
            name      = kubernetes_manifest.vault_cluster_issuer.manifest.metadata.name
            namespace = "cert-manager"
            kind      = "ClusterIssuer"
          }
        }
      }
    }
  })]

  depends_on = [helm_release.mariadb_operator_crds]
}
