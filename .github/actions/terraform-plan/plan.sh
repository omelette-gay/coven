#!/bin/bash
# Checks, plans and renders one coven stack for the terraform-plan action. Never prints the plan: it goes to a file,
# and only leaves the job (as plan.txt, for the pull request comment) once gitleaks has found nothing in it. Always
# exits 0 and sets the failed output instead, so outcomes.json is written whatever happens.

set -uo pipefail

case "$STACK" in
  bootstrap | platform | apps) ;;
  *)
    echo "::error::Unknown stack '$STACK'"
    exit 1
    ;;
esac

out="$RUNNER_TEMP/tfplan-artifact"
work="$RUNNER_TEMP/tfplan-work"
mkdir -p "$out" "$work/scan"
cd "$GITHUB_WORKSPACE/coven/$STACK" || exit 1

fmt=skipped init=skipped validate=skipped plan=skipped gitleaks=skipped

# fmt, init and validate don't touch any values, so their output can go to the log
if terraform fmt -check -diff; then fmt=success; else fmt=failure; fi

if terraform init -input=false -lockfile=readonly -no-color; then init=success; else init=failure; fi

if [ "$init" == success ]; then
  if terraform validate -no-color; then validate=success; else validate=failure; fi
fi

if [ "$validate" == success ]; then
  echo "Planning. The output goes to a file, not this log, and is posted on the pull request if gitleaks passes it."
  if terraform plan -no-color -input=false -lock=false -out="$work/tfplan" >"$work/plan-output.txt" 2>&1; then
    plan=success
    terraform show -no-color "$work/tfplan" >"$work/scan/plan.txt" 2>&1 || plan=failure
  else
    plan=failure
  fi
  # a failed plan's errors go in the comment instead, as they're no longer in the log
  if [ "$plan" == failure ]; then
    cp "$work/plan-output.txt" "$work/scan/plan.txt"
  fi

  if "$RUNNER_TEMP/gitleaks/gitleaks" dir "$work/scan" --no-banner --redact --log-level warn \
    --report-format json --report-path "$work/gitleaks.json"; then
    gitleaks=success
    cp "$work/scan/plan.txt" "$out/plan.txt"
  else
    if [ "$(jq length "$work/gitleaks.json" 2>/dev/null || echo 0)" -gt 0 ]; then
      gitleaks=found
      echo "::error::gitleaks found something that looks like a secret in the plan, so only the changed addresses are posted"
    else
      gitleaks=failure
      echo "::error::gitleaks failed, so only the changed addresses are posted"
    fi
    # Only the addresses and actions, from the saved plan. -json output has every value, including sensitive ones,
    # so it only ever goes to jq.
    {
      echo "The full plan is withheld because gitleaks didn't pass it ($gitleaks). Changes:"
      echo
      if [ -f "$work/tfplan" ]; then
        terraform show -json "$work/tfplan" | jq -r '
          [.resource_changes[]? | select(.change.actions != ["no-op"])]
          | if length == 0 then "No changes." else .[] | "\(.change.actions | join(",")) \(.address)" end'
      else
        echo "None, as the plan failed."
      fi
    } >"$out/plan.txt"
  fi
fi

jq -n --arg fmt "$fmt" --arg init "$init" --arg validate "$validate" --arg plan "$plan" --arg gitleaks "$gitleaks" \
  '{fmt: $fmt, init: $init, validate: $validate, plan: $plan, gitleaks: $gitleaks}' >"$out/outcomes.json"

rm -rf "$work"

failed=false
if [ "$init" != success ] || [ "$validate" != success ] || [ "$plan" != success ] || [ "$gitleaks" != success ]; then
  failed=true
fi

{
  echo "artifact-path=$out"
  echo "failed=$failed"
} >>"$GITHUB_OUTPUT"
