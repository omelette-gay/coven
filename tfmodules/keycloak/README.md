# Keycloak

Installs [Keycloak](https://www.keycloak.org/) (served under `/auth`) and its CNPG PostgreSQL cluster, backed up to
GCS. Called by the bootstrap stack. The realm, groups, clients and Terraform's own admin user are made by the platform
stack, through the keycloak provider, which needs Keycloak running.

## First start

On a fresh cluster, set `bootstrap_admin_password`. Keycloak then creates a temporary admin (`temp-admin`) in the master
realm with it when it first starts, which the platform stack logs in as for its first apply. Keycloak reads the password
from optional environment variables, so its Helm values are the same whether or not the Secret holding it exists, and
deleting it doesn't restart Keycloak. Delete the temporary admin and unset the password afterwards (see
[bootstrapping](../../docs/bootstrapping.md)). The password is in Terraform state while it's set.

## Backups

With `backup_bucket` set, the database backs up to `gs://<backup_bucket>/cnpg/keycloak/` with the service account key
the platform stack syncs from Vault, so on a fresh cluster backups fail until platform has been applied. The testlab
sets no bucket, so it doesn't back up.

## Metrics

Keycloak serves its metrics on its management port (9000), which the Ingress doesn't expose, and the chart's
ServiceMonitor scrapes them there. User events such as logins and failed logins are counted in
`keycloak_user_events_total`, labelled by realm, event and error. They don't need events to be turned on in the realm.
We used to use the aerogear keycloak-metrics-spi plugin for this, but it was downloaded from GitHub every time Keycloak
started, and it served its metrics on the public port, under each realm.

## Database image

The database takes its image from the shared ClusterImageCatalog (`postgresql_image_catalog`, see
[ADR 009](../../docs/adr/009-take-postgres-images-from-a-shared-image-catalog.md)), at the major version set in
`main.tf`. Changing the major upgrades the database in place, which takes Keycloak (and so SSO for everything) down for
a few minutes: follow "Major upgrades" in [backups and recovery](../../docs/backups-and-recovery.md#major-upgrades).
Its WAL archive is named after the major, e.g. `gs://<backup_bucket>/cnpg/keycloak/db-cluster-pg18/`. Backups from
PostgreSQL 16 are under `db-cluster/`.
