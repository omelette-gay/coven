#!/usr/bin/env bash
# Non-destructive check that the newest k3s datastore snapshot in GCS could be restored. Run as root on the controller.
#
# This never opens the live datastore. It downloads the snapshot into a temporary directory, and compares it against
# the running cluster through the Kubernetes API instead.

set -euo pipefail

# shellcheck source=common.sh
. /usr/local/lib/k3s-backup/common.sh

TOKEN_FILE=${K3S_TOKEN_FILE:-/var/lib/rancher/k3s/server/token}
KUBECTL=${KUBECTL:-k3s kubectl}

failures=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

work_dir=$(mktemp -d "$K3S_BACKUP_TMP_DIR/k3s-verify.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

# 1. download and decompress the newest snapshot
latest=$(latest_snapshot)
if [ -z "$latest" ]; then
  echo "FAIL: no snapshots found in $K3S_BACKUP_REMOTE"
  exit 1
fi
echo "newest snapshot: $latest"

# 2. integrity check (fetch_snapshot fails if it doesn't pass)
snapshot=$(fetch_snapshot "$latest" "$work_dir")
pass "integrity_check returned ok"

query() {
  sqlite3 -readonly "$snapshot" "$1"
}

# kine keeps every revision of each key (until compaction), and marks deletions by adding a row with deleted = 1. So
# the current state of a key is its row with the highest id.
LATEST_ROWS="SELECT k.* FROM kine k JOIN (SELECT MAX(id) AS id FROM kine GROUP BY name) m ON k.id = m.id"

# 3. is the snapshot recent?
snapshot_time=$(echo "$latest" | sed -E 's/^state-([0-9]{8})T([0-9]{2})([0-9]{2})([0-9]{2})Z\.db\.gz$/\1 \2:\3:\4 UTC/')
age_seconds=$(( $(date +%s) - $(date -d "$snapshot_time" +%s) ))
max_age_seconds=$(( K3S_BACKUP_INTERVAL_SECONDS * 2 ))
if [ "$age_seconds" -le "$max_age_seconds" ]; then
  pass "snapshot is $((age_seconds / 60)) minutes old"
else
  fail "snapshot is $((age_seconds / 60)) minutes old, more than twice the backup interval"
fi

# kine's row id is the revision, which Kubernetes exposes as the resourceVersion. The live revision only ever goes up,
# and with all the lease renewals on the cluster it'll be well ahead of the snapshot.
snapshot_revision=$(query "SELECT MAX(id) FROM kine;")
live_revision=$($KUBECTL get --raw '/api/v1/namespaces?limit=1' |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["metadata"]["resourceVersion"])')
if [ "$snapshot_revision" -gt 0 ] && [ "$snapshot_revision" -le "$live_revision" ]; then
  pass "snapshot revision $snapshot_revision, live revision $live_revision ($((live_revision - snapshot_revision)) writes since)"
else
  fail "snapshot revision $snapshot_revision doesn't make sense against live revision $live_revision"
fi

# these change slowly, so should normally match exactly - a small difference can be genuine change since the snapshot
echo
printf '%-14s %10s %10s\n' resource snapshot live
for resource in namespaces nodes secrets configmaps deployments; do
  case $resource in
    deployments) prefix=/registry/deployments/ ;;
    nodes) prefix=/registry/minions/ ;;
    *) prefix=/registry/$resource/ ;;
  esac
  snapshot_count=$(query "SELECT COUNT(*) FROM ($LATEST_ROWS) WHERE deleted = 0 AND name LIKE '$prefix%';")
  live_count=$($KUBECTL get "$resource" -A --no-headers 2>/dev/null | wc -l)
  printf '%-14s %10s %10s\n' "$resource" "$snapshot_count" "$live_count"
  if [ "$snapshot_count" -eq 0 ]; then
    fail "no $resource in the snapshot"
  fi
done
echo

# 4. Is the bootstrap data there? k3s keeps its CAs, service account key and the secrets encryption config in the
# datastore under /bootstrap/<first 12 hex characters of sha256(token)>, encrypted with a key derived from the token
# (see pkg/cluster/encrypt.go in k3s). Without it, the secrets in the snapshot can't be decrypted. The server token
# file is K10<ca hash>::server:<password>, and the password part is what k3s hashes.
token=$(cat "$TOKEN_FILE")
password=${token##*:}
expected_key=/bootstrap/$(printf '%s' "$password" | sha256sum | cut -c 1-12)
bootstrap_count=$(query "SELECT COUNT(*) FROM ($LATEST_ROWS) WHERE deleted = 0 AND name = '$expected_key' AND length(value) > 0;")
if [ "$bootstrap_count" -eq 1 ]; then
  pass "bootstrap data present at $expected_key"
else
  fail "no bootstrap data at $expected_key (bootstrap keys in snapshot: $(query "SELECT group_concat(name) FROM kine WHERE name LIKE '/bootstrap/%';"))"
fi

# with secrets-encryption enabled every secret should be stored encrypted (k8s:enc:<provider>:v1:<key name>:...)
unencrypted=$(query "SELECT COUNT(*) FROM ($LATEST_ROWS) WHERE deleted = 0 AND name LIKE '/registry/secrets/%' AND CAST(substr(value, 1, 8) AS TEXT) != 'k8s:enc:';")
if [ "$unencrypted" -eq 0 ]; then
  pass "all secrets in the snapshot are encrypted"
else
  fail "$unencrypted secrets in the snapshot are not encrypted"
fi

# 5. the temporary directory is cleaned up by the trap
echo
if [ "$failures" -eq 0 ]; then
  echo "all checks passed"
else
  echo "$failures check(s) failed"
  exit 1
fi
