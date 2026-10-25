@../docs/agents.md

## Claude Code specifics

- `.claude/settings.json` pre-approves read-only infrastructure commands and requires confirmation for ones that
  change state. Don't try to work around it (e.g. by wrapping commands in scripts or `bash -c`).
- Rules match on the start of the command, so put the subcommand first to get read-only commands auto-approved:
  `kubectl get pods -n vault`, not `kubectl -n vault get pods`; `cd coven && terraform plan`, not
  `terraform -chdir=coven plan`.
- When credentials are needed, ask the user to run `! ./login.sh --coven` so the login happens in this session.
