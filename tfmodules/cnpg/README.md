# CloudNativePG

Installs the [CloudNativePG](https://cloudnative-pg.io/) operator, which runs every PostgreSQL cluster (each app
installs its own with the `cluster` chart), and the barman-cloud plugin, which backs them up to GCS (see
[backups and recovery](../../docs/backups-and-recovery.md)). Called by the bootstrap stack. The plugin's webhook
certificate comes from cert-manager, so cert-manager must be installed first.

## Image catalog

The module also makes the ClusterImageCatalog every PostgreSQL cluster takes its image from (see
[ADR 007](../../docs/adr/007-take-postgres-images-from-a-shared-image-catalog.md)), named by `image_catalog_name`. It's
upstream's `catalog-minimal-trixie.yaml` from [cloudnative-pg/artifacts](https://github.com/cloudnative-pg/artifacts),
fetched at the commit pinned in `main.tf`, which Renovate updates weekly. Planning fetches it from GitHub.

When a catalog image changes, the operator rolls every cluster on that major: standbys first, then a switchover. It waits
`clusters_rollout_delay` seconds between clusters and `instances_rollout_delay` between instances, so they don't all
restart at once.
