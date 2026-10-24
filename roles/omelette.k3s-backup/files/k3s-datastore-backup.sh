#!/usr/bin/env bash
# Takes a consistent point-in-time snapshot of the k3s SQLite datastore, checks it, and uploads it to GCS. On success
# it records when it last succeeded for node-exporter's textfile collector.
#
# This only ever reads the live datastore, through SQLite's online backup API. It never copies the database file or
# WAL directly, as doing that while k3s is writing to them gives a torn copy.

set -euo pipefail

# shellcheck source=common.sh
. /usr/local/lib/k3s-backup/common.sh

STATE_DIR=${K3S_BACKUP_STATE_DIR:-/var/lib/k3s-backup}
METRIC_DIR=${K3S_BACKUP_METRIC_DIR:-/run/node-exporter}
METRIC_NAME=k3s-datastore-backup.prom

if [ ! -f "$K3S_BACKUP_DB_PATH" ]; then
  echo "datastore $K3S_BACKUP_DB_PATH doesn't exist" >&2
  exit 1
fi

work_dir=$(mktemp -d "$K3S_BACKUP_TMP_DIR/k3s-backup.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

# The snapshot is written to the same filesystem as the live datastore, so make sure there's plenty of room first.
# Filling the disk would hurt k3s far more than a missed backup would. The snapshot can be as big as the database plus
# its WAL, and it needs space for both the snapshot and its compressed copy.
db_bytes=$(stat -c %s "$K3S_BACKUP_DB_PATH")
wal_bytes=$(stat -c %s "$K3S_BACKUP_DB_PATH-wal" 2>/dev/null || echo 0)
needed_bytes=$(( (db_bytes + wal_bytes) * 2 ))
free_bytes=$(df --output=avail -B1 "$work_dir" | tail -n 1)
if [ "$free_bytes" -lt "$needed_bytes" ]; then
  echo "not enough free space in $K3S_BACKUP_TMP_DIR: need $needed_bytes bytes, have $free_bytes" >&2
  exit 1
fi

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
snapshot=$work_dir/state-$timestamp.db

# This uses SQLite's online backup API to copy the whole database in a single step, which holds one read transaction
# for the length of the copy (well under a second for a few hundred MB). With WAL, readers don't block writers, so k3s
# keeps writing throughout, and the copy is consistent as of the start of the read.
#
# We don't use the sqlite3 CLI's .backup command for this. It copies 100 pages at a time and releases its lock between
# steps, and SQLite restarts a backup from scratch whenever another process writes to the source between steps. kine
# writes constantly, so it never finishes - in testing it couldn't back up a 100MB database within a minute with as
# few as 20 writes a second. Python is always available, as Ansible needs it.
#
# The source is opened read-only, so this connection can never write to the live datastore or checkpoint its WAL. The
# timeout covers the brief moments where SQLite needs a lock to start the read.
python3 -I - "$K3S_BACKUP_DB_PATH" "$snapshot" <<'EOF'
import sqlite3
import sys

source = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True, timeout=60)
destination = sqlite3.connect(sys.argv[2])
source.backup(destination)  # pages=-1 by default, i.e. everything in one step
destination.close()
source.close()
EOF

check_integrity "$snapshot"

gzip "$snapshot"
rclone copyto "$snapshot.gz" "$K3S_BACKUP_REMOTE/$(basename "$snapshot.gz")"
size_bytes=$(stat -c %s "$snapshot.gz")
echo "uploaded $(basename "$snapshot.gz") ($size_bytes bytes) to $K3S_BACKUP_REMOTE"

# /run is a tmpfs, so the metrics are written to $STATE_DIR first and then copied into the textfile directory. The
# k3s-datastore-backup-metrics service copies them back into /run after a reboot, so the last success time survives
# reboots rather than the metric disappearing.
mkdir -p "$STATE_DIR" "$METRIC_DIR"
metric_tmp=$(mktemp "$STATE_DIR/$METRIC_NAME.XXXXXX")
cat >"$metric_tmp" <<EOF
# HELP k3s_datastore_backup_last_success_timestamp_seconds Unix time of the last successful k3s datastore backup.
# TYPE k3s_datastore_backup_last_success_timestamp_seconds gauge
k3s_datastore_backup_last_success_timestamp_seconds $(date +%s)
# HELP k3s_datastore_backup_size_bytes Compressed size of the last successful k3s datastore backup.
# TYPE k3s_datastore_backup_size_bytes gauge
k3s_datastore_backup_size_bytes $size_bytes
# HELP k3s_datastore_backup_interval_seconds How often the k3s datastore backup is configured to run.
# TYPE k3s_datastore_backup_interval_seconds gauge
k3s_datastore_backup_interval_seconds $K3S_BACKUP_INTERVAL_SECONDS
EOF
chmod 644 "$metric_tmp"
mv "$metric_tmp" "$STATE_DIR/$METRIC_NAME"

# node-exporter only reads *.prom, so the temporary name keeps it from reading a half-written file
cp "$STATE_DIR/$METRIC_NAME" "$METRIC_DIR/$METRIC_NAME.tmp"
mv "$METRIC_DIR/$METRIC_NAME.tmp" "$METRIC_DIR/$METRIC_NAME"
