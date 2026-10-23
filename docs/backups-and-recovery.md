# Backups and Recovery

## Disk volumes

Longhorn will back up any volume where the PVC has the correct labels on it. The labels to add are:

```yaml
      recurring-job.longhorn.io/source: enabled
      recurring-job.longhorn.io/nightly-backup: enabled
```

To restore, first stop any service that's using that volume (e.g., uninstall the Helm chart for the service, or scale
the deployment to 0 `kubectl -n <namespace> scale deployment/<app-name> --replicas=0`). 

You can now rollback the volume in the Longhorn UI (access this with `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8000:80`
and accessing http://localhost:8000/). Find the volume you want to restore and then you can revert to a previous snapshot
if you want to do so in place using the menu options. You can now restart the service that was using the volume.

## PostgreSQL databases

Postgres databases are backed up using the cloudnative-pg operator. You will first need to ensure that the
backups/service-account-key secret from Vault is synced into the same k8s namespace as the database using the
External Secrets Operator. Then you can add the following to the Helm chart used to deploy the cluster:

```yaml
  backups:
    enabled: true
    method: plugin
    pluginConfiguration:
      name: barman-cloud.cloudnative-pg.io
    provider: google
    google:
      bucket: coven-backups
      path: /cnpg/<db-name>/
    secret:
      name: <gcp-backup-creds-secret-name>
      create: false
    scheduledBackups:
      - name: daily-backup
        schedule: "0 0 9,21 * * *" # e.g., for 9am and 9pm
        backupOwnerReference: self
        method: plugin
        pluginConfiguration:
          name: barman-cloud.cloudnative-pg.io
```

This will create daily snapshots, as well as enabling continuous backup of the WALs to allow finer-grained
point-in-time recovery.

To restore a backup, the best way to do this is to uninstall the Helm chart and recreate the database from scratch.
First off, rename the folder the backup is in (the one defined in `backups.google.path`) to `<db-name>-old` (or
similar) so the new database's backups don't overwrite the old ones. Then alter the values in the cluster Helm chart
to tell it to restore from the backup on create:

```yaml
      mode: recovery
      recovery:
        method: plugin
        pluginConfiguration:
          name: barman-cloud.cloudnative-pg.io
        pitrTarget:
          time: <recovery in ISO 8601 format e.g,. 2026-08-13T04:00:00Z>
        database: <name of database in the cluster (probably specified in the previous initdb block)>

        provider: google
        google:
          bucket: coven-backups
          path: "/cnpg/<db-name>-old/" # or whatever you renamed the old backup folder to
        secret:
          create: false
          name: <gcp-backup-creds-secret-name>
```

You will then want to tidy this up by reverting the values file to the previous version, and once you are confident
that the restore has completed, you can delete the old backup folder (as it will no longer be auto expired).

## MariaDB databases

To backup MariaDB databases, first sync the backups/service-account-creds secret from Vault into the same k8s namespace
as the database using the External Secrets Operator.

Then to enable backups, you can add this block to the Helm chart:

```yaml
  physicalBackups:
    - name: nightly
      schedule:
        cron: "18 22 * * *" # for 22:18 for example
      storage:
        s3:
          bucket: coven-backups
          prefix: mariadb/<db-name>
          region: europe-west2
          endpoint: storage.googleapis.com
          accessKeyIdSecretKeyRef:
            name: <gcp-backup-creds-secret-name>
            key: AWS_ACCESS_KEY_ID
          secretAccessKeySecretKeyRef:
            name: <gcp-backup-creds-secret-name>
            key: AWS_SECRET_ACCESS_KEY
      compression: gzip
```

To restore a backup, you can uninstall the existing Helm chart and then delete the pvc associated with it to ensure it
is fully deleted (`kubectl -n <namespace> get pvc`, then `kubectl -n <namespace> delete pvc <pvc-name>`). Now you
recreate it specifying the backup to restore in the Helm values:

```yaml
  mariadb:
    bootstrapFrom:
      backupRef:
        name: nightly
        kind: PhysicalBackup
      targetRecoveryTime: <recovery in ISO 8601 format e.g,. 2026-08-13T04:00:00Z>
```

Once this is done, you can then revert the values change to remove the bootstrapFrom block and back to the previous
values.

## K3s control plane & SQLite state

The K3s API datastore (`state.db`) is continuously replicated to GCP Cloud Storage using Litestream running as a
systemd service on the controller node. This file is encrypted with the cluster token, which is stored as a GCP secret
to avoid circular dependencies.

In the event of complete controller failure, the state will be restored from the bucket, and then Longhorn should start
re-replicating the volumes over from a surviving worker (if needed) once that re-connects to the cluster.
You will need to provide the GCP service account credentials to allow the restore to happen (assuming Vault is down,
and therefore they cannot be fetched from Vault as per usual). You can do this by passing the following additional
arg to ansible-playbook: `--extra-vars "vault_gcp_litestream_service_account_json='{{ lookup(\"file\", \"path/to/gcp-service-account.json\") }}'"`.
