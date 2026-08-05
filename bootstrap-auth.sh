#!/bin/bash

set -e

if [ "$1" == "--coven" ] ; then
  export SSH_ARGS=strix.xdc.omelette.gay
elif [ "$1" == "--local" ] ; then
  export SSH_ARGS=-i .vagrant/machines/default/*/private_key vagrant@192.168.57.100
else
  echo "usage: $0 [--coven|--local]"
  exit 1
fi

cert_temp=$(mktemp)
key_temp=$(mktemp)
trap 'rm -f -- "$cert_temp" "$key_temp" ${ca_temp:+"$ca_temp"}' EXIT

# fetch k3s system user credentials
k3s_config=$(ssh $SSH_ARGS sudo cat /etc/rancher/k3s/k3s.yaml)

echo "$k3s_config" | awk '/client-certificate-data:/ {print $2}' | base64 --decode > "$cert_temp"
echo "$k3s_config" | awk '/client-key-data:/ {print $2}' | base64 --decode > "$key_temp"

# create kubectl context
if [ "$1" == "--coven" ] ; then
  ca_temp=$(mktemp)

  curl -k https://strix.xdc.omelette.gay:6443/cacerts > $ca_temp
  kubectl config set-cluster coven --server=https://strix.xdc.omelette.gay:6443 --embed-certs --certificate-authority=$ca_temp
  kubectl config set-credentials coven --client-certificate=$cert_temp --client-key=$key_temp --embed-certs
  kubectl config set-context coven --cluster=coven --user=coven
  kubectl config use-context coven
elif [ "$1" == "--local" ] ; then
  kubectl config set-cluster local --server=https://192.168.57.100:6443 --insecure-skip-tls-verify=true
  kubectl config set-credentials local --client-certificate=$cert_temp --client-key=$key_temp --embed-certs
  kubectl config set-context local --cluster=local --user=local
  kubectl config use-context local
fi
