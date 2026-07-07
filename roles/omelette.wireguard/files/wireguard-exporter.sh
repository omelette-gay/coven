#!/usr/bin/env bash

output_file_name=$1

if [ -z "$output_file_name" ] ; then
  echo "usage: $0 output_file_name"
  exit 1
fi

mkdir -p "`dirname $output_file_name`"

TEXTFILE_TMP=`mktemp`
chmod 644 $TEXTFILE_TMP

{
  echo "# HELP wireguard_latest_handshake_seconds Unix time of the last handshake with the peer."
  echo "# TYPE wireguard_latest_handshake_seconds gauge"

  # Dump wireguard stats
  # wg show all dump outputs: interface public_key preshared_key endpoint allowed_ips latest_handshake transfer_rx transfer_tx persistent_keepalive
  wg show all dump | awk '{
    # Only parse lines representing peers (field 5 is allowed_ips, interface lines only have 4 fields)
    if (NF > 5) {
      interface=$1
      peer=$2
      endpoint=$4
      handshake=$6
      rx=$7
      tx=$8
      keepalive=$9

      # Handle the "off" string for persistent keepalive
      if (keepalive == "off") {
        keepalive = 0
      }

      # Format the labels safely
      labels = sprintf("interface=\"%s\",peer=\"%s\",endpoint=\"%s\"", interface, peer, endpoint)

      print "wireguard_latest_handshake_seconds{" labels "} " handshake
      print "wireguard_transfer_rx_bytes_total{" labels "} " rx
      print "wireguard_transfer_tx_bytes_total{" labels "} " tx
      print "wireguard_persistent_keepalive_seconds{" labels "} " keepalive
    }
  }'
} > "$TEXTFILE_TMP"

mv "$TEXTFILE_TMP" "$output_file_name"
