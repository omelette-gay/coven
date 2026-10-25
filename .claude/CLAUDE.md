@../docs/agents.md

## Claude Code specifics

- `.claude/settings.json` pre-approves read-only infrastructure commands and environment setup, and requires
  confirmation for commands that change state. Don't try to work around it (e.g. by wrapping commands in scripts or
  `bash -c`).
- Read-only commands are matched on the start of the command, so put the subcommand first to get them pre-approved:
  `kubectl get pods -n vault`, not `kubectl -n vault get pods`; `cd coven && terraform plan`, not
  `terraform -chdir=coven plan`. On Windows, the same applies after the `wsl --shell-type login ` prefix.
- In `.claude/settings.json`, each pre-approved command is listed three times: for macOS and WSL (`Bash(...)`), and
  for Windows (`Bash(wsl --shell-type login ...)` and `PowerShell(wsl --shell-type login ...)`). Keep all three in
  step when adding one. Ask and deny rules use leading wildcards (`*kubectl* delete*`) so they also catch wrapped
  commands.
- When credentials are needed, ask the user to run `! ./login.sh --coven` so the login happens in this session.
