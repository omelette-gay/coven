# CloudNativePG

Installs the [CloudNativePG](https://cloudnative-pg.io/) operator, which runs every PostgreSQL cluster (each app
installs its own with the `cluster` chart), and the barman-cloud plugin, which backs them up to GCS (see
[backups and recovery](../../docs/backups-and-recovery.md)). Called by the bootstrap stack. The plugin's webhook
certificate comes from cert-manager, so cert-manager must be installed first.
