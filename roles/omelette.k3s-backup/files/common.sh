# Shared functions for the k3s-datastore-* scripts. This is sourced, not run.

# without this, `set -e` doesn't apply inside $(...), so a failure part way through a function whose output is being
# captured (e.g. a failed download in fetch_snapshot) would be silently ignored
shopt -s inherit_errexit

K3S_BACKUP_ENV=${K3S_BACKUP_ENV:-/etc/k3s-backup/k3s-backup.env}

if [ ! -r "$K3S_BACKUP_ENV" ]; then
  echo "can't read $K3S_BACKUP_ENV" >&2
  exit 1
fi

# export everything so rclone picks up the RCLONE_* settings
set -a
# shellcheck source=/dev/null
. "$K3S_BACKUP_ENV"
set +a

# temporary files go on disk rather than in /tmp, as the snapshot can be large
K3S_BACKUP_TMP_DIR=${K3S_BACKUP_TMP_DIR:-/var/tmp}

# prints the name of the newest snapshot in the bucket, or nothing if there are no snapshots. Exits non-zero if the
# bucket couldn't be listed, so that callers can tell "no backups" apart from "couldn't check for backups".
latest_snapshot() {
  local listing rc=0
  # only look at our own snapshots, not the old Litestream files under state.db/
  listing=$(rclone lsf --files-only --include 'state-*.db.gz' "$K3S_BACKUP_REMOTE/") || rc=$?

  case $rc in
    0) ;;
    3) listing="" ;; # rclone exits 3 for "directory not found", i.e. nothing has ever been uploaded under the prefix
    *)
      echo "failed to list snapshots in $K3S_BACKUP_REMOTE (rclone exit code $rc)" >&2
      return 1
      ;;
  esac

  # the names contain a UTC timestamp, so sorting them puts the newest last
  printf '%s\n' "$listing" | sed '/^$/d' | sort | tail -n 1
}

# downloads and decompresses a snapshot, then checks it is a valid SQLite database. Prints the path to the database.
fetch_snapshot() {
  local name=$1 dest_dir=$2

  rclone copyto "$K3S_BACKUP_REMOTE/$name" "$dest_dir/$name" >&2
  gunzip "$dest_dir/$name"

  local db=$dest_dir/${name%.gz}
  check_integrity "$db"
  echo "$db"
}

check_integrity() {
  local result
  result=$(sqlite3 -readonly "$1" "PRAGMA integrity_check;")
  if [ "$result" != "ok" ]; then
    echo "integrity check failed for $1:" >&2
    echo "$result" >&2
    return 1
  fi
}
