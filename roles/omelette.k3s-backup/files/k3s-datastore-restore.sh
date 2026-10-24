#!/usr/bin/env bash
# Disaster recovery: if the k3s datastore is missing, restore it from the newest snapshot in GCS. This must run before
# k3s is started, and does nothing at all if the datastore already exists.
#
# Prints "restored <snapshot>" if it restored something, which Ansible uses to report a change.

set -euo pipefail

# shellcheck source=common.sh
. /usr/local/lib/k3s-backup/common.sh

if [ -e "$K3S_BACKUP_DB_PATH" ]; then
  echo "$K3S_BACKUP_DB_PATH already exists, not restoring"
  exit 0
fi

# If listing fails this exits non-zero, rather than carrying on as if there were no backups. Otherwise a credentials
# problem would quietly lead to k3s creating a brand new, empty cluster.
latest=$(latest_snapshot)

if [ -z "$latest" ]; then
  echo "no snapshots found in $K3S_BACKUP_REMOTE, nothing to restore"
  exit 0
fi

work_dir=$(mktemp -d "$K3S_BACKUP_TMP_DIR/k3s-restore.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

restored_db=$(fetch_snapshot "$latest" "$work_dir")

db_dir=$(dirname "$K3S_BACKUP_DB_PATH")
install -d -m 0700 "$db_dir"
# copy next to the destination and then rename, so the datastore either appears complete or not at all
install -m 0600 "$restored_db" "$K3S_BACKUP_DB_PATH.restoring"
mv "$K3S_BACKUP_DB_PATH.restoring" "$K3S_BACKUP_DB_PATH"

echo "restored $latest"
