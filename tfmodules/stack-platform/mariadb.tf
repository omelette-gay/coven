# The MariaDB operator, for apps that use MariaDB
module "mariadb_operator" {
  source = "../mariadb-operator"

  # its webhook certificate comes from Vault's CA
  cluster_issuer = kubernetes_manifest.vault_cluster_issuer.manifest.metadata.name
}
