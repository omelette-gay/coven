# MariaDB operator

Installs the [MariaDB operator](https://github.com/mariadb-operator/mariadb-operator) and its CRDs, for apps that use
MariaDB. Called by the platform stack. Its webhook certificate comes from `cluster_issuer`, Vault's CA.
