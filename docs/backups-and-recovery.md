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

The k3s API datastore is a SQLite database (`/var/lib/rancher/k3s/server/db/state.db`) on the controller.
The `omelette.k3s-backup` Ansible role installs a systemd timer (`k3s-datastore-backup.timer`) which takes a snapshot of
it every 6 hours (`k3s_backup_interval_hours`). If strix was down when a backup was due, it runs as soon as strix boots.

Snapshots are deleted after 14 days by a lifecycle rule on the bucket in [coven/backups.tf](../coven/backups.tf), which
only applies to objects under `k3s/`.

This means we can lose up to about 6.5 hours of cluster state. That's fine, because almost everything in the datastore
is recreated by Ansible, Terraform and app deploys, and the data that matters is backed up separately by Longhorn,
CNPG and MariaDB (above).

To take a backup straight away, run `sudo systemctl start k3s-datastore-backup` on strix, and check how it went with
`journalctl -u k3s-datastore-backup`.

For why we take snapshots rather than replicating continuously, and what does and doesn't protect a snapshot, see
[ADR 001](./adr/001-replace-litestream-with-snapshots.md).

### Checking a backup can be restored

`k3s-datastore-backup-verify` checks the newest snapshot without touching the live datastore. Run it on strix whenever
you want confidence in the backups, and after anything changes how they're taken:

```shell
sudo k3s-datastore-backup-verify
```

It downloads the newest snapshot to the temporary directory, and verifies it.
It prints `PASS` or `FAIL` for each check and exits non-zero if any fail.

### Automatic restore when the datastore is missing

When the Ansible playbook runs, `omelette.k3s-backup` runs before k3s is installed or started (see
[plays/configure-hosts.yml](../plays/configure-hosts.yml)). If `state.db` doesn't exist on the controller, it runs
`k3s-datastore-restore`, which downloads the newest snapshot, checks its integrity and puts it in place. If `state.db`
exists it does nothing at all, so it can never overwrite a running cluster's datastore.

If there are no snapshots for the host, it does nothing and k3s creates a new, empty cluster. But if it can't list the
bucket at all (for example because the credentials are wrong) it fails the playbook, rather than letting k3s start an
empty cluster when there may be a backup it couldn't see.

### Disaster recovery: rebuilding the controller

> [!WARNING]
> **This procedure has never been carried out end to end.** The only part that has been verified on coven is the
> non-destructive `k3s-datastore-backup-verify` check above. Everything below is based on how the Ansible role and k3s
> are designed to work, not on having done it. Read it all before starting, and expect to have to adapt it. If you
> ever use it, please update this section with what actually happened.

Use this if strix's datastore is lost or corrupted, or strix has to be rebuilt. strix is the only controller, so the
Kubernetes API, and with it Vault, will be down throughout.

1. **Check there's a usable snapshot.** If strix is still running, run `sudo k3s-datastore-backup-verify`. Otherwise
   look in the bucket in the GCP console, under `coven-backups/k3s/strix/`. The restore uses the newest
   `state-*.db.gz`. If the newest one is bad (e.g. it was taken after whatever went wrong), see
   [restoring an older snapshot](#restoring-an-older-snapshot) instead.
2. **Get strix to a state where the restore will run.**
   - If strix is being rebuilt from scratch, install Rocky Linux 9 with the same hostname and set up SSH access so
     Ansible can reach it as before.
   - If the existing install is still there, stop k3s with `sudo systemctl stop k3s` and move its server state out of
     the way, so that the restore runs and k3s doesn't find state on disk that doesn't match the restored datastore:
     `sudo mv /var/lib/rancher/k3s/server /var/lib/rancher/k3s/server.broken-$(date +%F)`. Don't delete it until the
     cluster is working again. (Unverified: k3s may well cope with keeping `server/tls` and `server/cred`, as they
     should match the bootstrap data, but moving the whole directory is the safer option.)
3. **Get credentials, as Vault will be down.**
   - GCP: run `gcloud auth application-default login` as someone with access to the `coven-omelette-gay` project. The
     playbook needs this to read the cluster token from Secret Manager.
   - The backup service account key: create a new one in the GCP console (IAM → Service accounts → `coven-backup` →
     Keys → Add key → JSON) and save it locally. Delete it once Vault is back, as Terraform manages the usual key.
4. **Run the host part of the playbook against strix only**, passing the key in place of the Vault lookup.
   This playbook doesn't include the cluster-level services, which need Vault, and `bootstrap=true` skips the Vault
   lookups in the host config:

   ```shell
   uv run ansible-playbook -i coven/inventory plays/configure-hosts.yml --limit strix -e bootstrap=true \
     --extra-vars "k3s_backup_gcp_service_account_json='{{ lookup(\"file\", \"path/to/gcp-service-account.json\") }}'"
   ```

   The "Restore the k3s datastore from the newest backup if it is missing" task should report a change, and its output
   should include the name of the snapshot it restored.

   (Unverified: `bootstrap=true` also skips strix's WireGuard private key, which comes from Vault. strix's k3s
   `node-ip` and flannel interface are its WireGuard address and `wg0`, so k3s may not come up properly without the
   tunnel. If it doesn't, pass `wireguard_private_key` as an extra var too, from wherever you can get it with Vault
   down, and leave out `bootstrap=true`.)
5. **Check k3s is up** with `sudo k3s kubectl get nodes` on strix, then **unseal Vault** (see
   [diagnosing issues](./diagnosing-issues.md#vaultissealed)).
6. **Run the normal deploy** by re-running the "Configure Coven hosts" and "Deploy cluster configuration" GitHub
   Actions workflows, so that everything, including the cluster-level services and the normal backup credentials, is
   put back as it should be. Then delete
   the service account key you created in step 3.
7. **Expect things to be out of date.** Anything that changed in the cluster after the snapshot was taken (up to about
   6.5 hours) is lost. Ansible, Terraform and app deploys put back most of it, so re-run the Terraform workflow and any
   app deploys from that window. Longhorn should re-replicate volumes from grimhilde once it reconnects. CNPG and
   MariaDB can be restored from their own backups if their data doesn't match.
8. **Check backups are running again:** `systemctl list-timers k3s-datastore-backup.timer` on strix should show the
   next run, and the `K3sDatastoreBackupStale` and `K3sDatastoreBackupMissing` alerts shouldn't be firing.

#### Restoring an older snapshot

The automatic restore always uses the newest snapshot. To use an older one, do steps 2 and 3 above, then run this on
strix, with k3s stopped, no `state.db`, and the backup role installed by an earlier Ansible run:

```shell
sudo -i
. /usr/local/lib/k3s-backup/common.sh
cd "$(mktemp -d /var/tmp/k3s-restore.XXXXXX)"
rclone lsf "$K3S_BACKUP_REMOTE/"                          # pick the snapshot you want
rclone copyto "$K3S_BACKUP_REMOTE/state-<timestamp>.db.gz" state.db.gz
gunzip state.db.gz
sqlite3 state.db "PRAGMA integrity_check;"                # must print "ok"
install -d -m 0700 /var/lib/rancher/k3s/server/db
install -m 0600 state.db /var/lib/rancher/k3s/server/db/state.db
```

Then carry on from step 4. The restore task will see that `state.db` exists and leave it alone.

### Backup credentials going stale

The backup service account key on strix is written by Ansible, so it only changes when the "Configure Coven hosts"
workflow runs (on merges to `main`). Terraform replaces the key every 30 days and deletes the old one, so if nothing
has been merged since the key was rotated, uploads fail with an authentication error and `K3sDatastoreBackupStale`
fires. Re-running the "Configure Coven hosts" workflow fixes it.
