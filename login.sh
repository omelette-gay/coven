#!/bin/bash

set -e

if [ "$1" == "--coven" ] ; then
  export VAULT_ADDR=https://vault.coven.omelette.gay
elif [ "$1" == "--local" ] ; then
  export VAULT_ADDR=https://vault.coven.local
  export VAULT_SKIP_VERIFY=1
else
  echo "usage: $0 [--coven|--local]"
  exit 1
fi

# login with Vault
vault login -method=oidc -path=keycloak role=admin

# get k8s cluster token
k8s_token=$(vault write -field service_account_token kubernetes/creds/admin cluster_role_binding=true kubernetes_namespace=default)

# create kubectl context
if [ "$1" == "--coven" ] ; then
  ca_temp=$(mktemp)
  trap '{ rm -f -- "$ca_temp"; }' EXIT

  curl -k https://strix.xdc.omelette.gay:6443/cacerts > $ca_temp
  kubectl config set-cluster coven --server=https://strix.xdc.omelette.gay:6443 --embed-certs --certificate-authority=$ca_temp
  kubectl config set-credentials coven --token=$k8s_token
  kubectl config set-context coven --cluster=coven --user=coven
  kubectl config use-context coven
elif [ "$1" == "--local" ] ; then
  kubectl config set-cluster local --server=https://192.168.57.100:6443 --insecure-skip-tls-verify=true
  kubectl config set-credentials local --token=$k8s_token
  kubectl config set-context local --cluster=local --user=local
  kubectl config use-context local
fi
