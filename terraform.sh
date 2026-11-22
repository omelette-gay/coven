#!/bin/bash
# Plans or applies one Terraform stack, or all three in order (bootstrap, platform, apps). See
# docs/adr/002-three-stack-terraform-for-cluster-configuration.md.
#
# This is how the testlab is run. On coven, CI applies every merge to main, so only use this as break-glass.
#
# Log in first with ./login.sh, or ./bootstrap-auth.sh if Vault or Keycloak is down. Any arguments after the stack are
# passed on to Terraform, e.g. ./terraform.sh --local plan platform -target=module.platform.module.glitchtip

set -euo pipefail

usage() {
  echo "usage: $0 [--coven|--local] [plan|apply] [bootstrap|platform|apps|all] [terraform arguments...]" >&2
  exit 1
}

[ $# -ge 3 ] || usage

case "$1" in
  --coven)
    environment=coven
    export VAULT_ADDR=https://vault.coven.omelette.gay
    ;;
  --local)
    environment=testlab
    export VAULT_ADDR=https://vault.coven.local
    export VAULT_SKIP_VERIFY=1
    ;;
  *) usage ;;
esac

case "$2" in
  plan | apply) action=$2 ;;
  *) usage ;;
esac

case "$3" in
  all) stacks=(bootstrap platform apps) ;;
  bootstrap | platform | apps) stacks=("$3") ;;
  *) usage ;;
esac

shift 3

cd "$(dirname "$0")"

# coven's providers use the current kubectl context, so make sure it's coven's and not the testlab's. The testlab's
# providers always use the "local" context.
if [ "$environment" == "coven" ] ; then
  context=$(kubectl config current-context 2>/dev/null || true)
  if [ "$context" != "coven" ] ; then
    echo "The current kubectl context is '$context', not 'coven'. Run ./login.sh --coven first." >&2
    exit 1
  fi
fi

# coven's bootstrap stack can't read Vault, so give it the Hetzner token through the environment, as CI does. The
# testlab uses a dummy token.
if [ "$environment" == "coven" ] && [ -z "${HCLOUD_TOKEN:-}" ] && [[ " ${stacks[*]} " == *" bootstrap "* ]] ; then
  HCLOUD_TOKEN=$(vault kv get -field=api_token secret/gitops/hetzner)
  export HCLOUD_TOKEN
fi

for stack in "${stacks[@]}" ; do
  echo "==> terraform $action $environment/$stack"
  terraform -chdir="$environment/$stack" "$action" "$@"
done
