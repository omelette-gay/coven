#!/usr/bin/env bash

output_file_name=$1

if [ -z "$output_file_name" ] ; then
  echo "usage: $0 output_file_name"
  exit 1
fi

needs-restarting -r >/dev/null 2>&1
node_reboot_required=$?

mkdir -p "`dirname $output_file_name`"
cat >$output_file_name <<EOF
# HELP node_reboot_required Node reboot is required for software updates.
# TYPE node_reboot_required gauge
node_reboot_required $node_reboot_required
EOF
