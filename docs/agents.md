# Agent instructions

Infrastructure as code for Chris & Meg's k3s cluster ("coven") and home network. This file is a map: the detail lives
in the rest of [docs/](./), which is written with AI agents in mind. Read the relevant doc before making changes.

## Where to look

| Doc | Read it when |
|---|---|
| [docs/cluster-overview.md](./cluster-overview.md) | Before any non-trivial change. Nodes, networking, which tool owns what, platform services, automatic maintenance |
| [docs/diagnosing-issues.md](./diagnosing-issues.md) | Investigating an alert or error on the cluster. Has ground rules, tools, port-forwards and per-alert guides |
| [docs/backups-and-recovery.md](./backups-and-recovery.md) | Anything touching Longhorn, CNPG, MariaDB or k3s datastore backups and restores |
| [docs/deploying-apps.md](./deploying-apps.md) | Adding or changing a self-deploying app (`coven/apps/`) |
| [docs/secrets.md](./secrets.md) | How Vault, External Secrets and auth fit together |
| [docs/sso.md](./sso.md) | Adding or changing a Keycloak client, putting an app behind SSO, or giving someone a Keycloak account |
| [docs/https.md](./https.md) | Exposing a service: Traefik, cert-manager, external-dns |
| [docs/names-and-numbers.md](./names-and-numbers.md) | Naming hosts/domains, IP ranges |
| [docs/bootstrapping.md](./bootstrapping.md) | Building something from scratch |
| [docs/adr/](./adr/README.md) | Before reversing a deliberate choice; when making a hard-to-undo decision |
| [docs/incidents/](./incidents/README.md) | When an alert or symptom looks familiar; after fixing an incident |
| [README.md](../README.md) | Local setup, testlab, Vault unseal and other how-tos |

## Repo layout

- `plays/` - Ansible playbooks. `configure-hosts.yml` configures hosts; `configure-cluster.yml` configures the cluster
  services that haven't moved to Terraform yet; `rolling-reboot.yml` reboots nodes safely.
- `roles/omelette.*` - our Ansible roles. External roles (e.g. `xanmanning.k3s`) come from `requirements.yml`.
- `coven/` - production: the Ansible inventory (`coven/inventory/`) and three Terraform stacks, applied in order:
  `coven/bootstrap/`, `coven/platform/` and `coven/apps/` (see
  [ADR 002](./adr/002-three-stack-terraform-for-cluster-configuration.md)).
- `testlab/` - the local Vagrant VM: same shape as `coven/`, with local Terraform state.
- `tfmodules/` - Terraform modules used by `coven/` and `testlab/`. `stack-bootstrap/` and `stack-platform/` hold the
  content of those stacks, shared by both environments; apps differ between environments, so each environment's
  `apps/` defines them directly.
- `Chart.yaml` - not a real chart. It pins Helm chart versions so Renovate can bump them; Ansible reads them with the
  `helm_chart` lookup plugin in `lookup_plugins/`.
- `.github/workflows/` - CI/CD (see below).

## Key facts

- **Deploys happen from GitHub Actions on merge to `main`**: `host_config.yml` runs `plays/configure-hosts.yml`, and
  `tfapply.yml` applies the Terraform stacks in order, then runs `plays/configure-cluster.yml`. `tfplan.yml` posts a Terraform plan on every PR. A change isn't
  done until it's in code and merged; manual changes on the cluster get reverted or cause drift.
- **Ansible → Terraform migration is in progress.** Host config stays in Ansible; cluster services are moving to
  Terraform, and new work should prefer Terraform. Some things exist in both (see the cluster overview).
- **Self-deploying apps** (e.g. `wedding`, `home-assistant`) are defined in their own repos. This repo only sets up
  their namespace, Vault access, secrets and SSO client.
- **Secrets live in Vault, never in the repo.**
- **Keycloak doesn't restrict which apps a user can log in to.** Any user in the `omelette.gay` realm can log in to
  any client, and each app decides what they can do. Read [docs/sso.md](./sso.md) before adding a Keycloak client.
- **New features go to the testlab first**; bug fixes can go straight to coven.

## Environment

We work on macOS or Windows. **On Windows, everything in this repo runs under WSL** (Ansible doesn't run on
Windows). The only exception there is Vagrant, which runs on the Windows side and is driven from WSL with
`./vagrant.ps1` (see the README).

Check where you're running before running anything:

- **macOS or Linux (including inside WSL)**: run commands directly.
- **Natively on Windows** (`C:\` paths, PowerShell or Git Bash, no `uv`/`ansible`), e.g. VS Code without the WSL
  extension: run each tool through WSL by prefixing the command with exactly `wsl --shell-type login `
  (e.g. `wsl --shell-type login kubectl get pods -A`). The login shell loads the user's profile, so tools in
  `~/.local/bin` such as `uv` are found. Don't use other spellings (`wsl.exe`, `wsl -e`, `bash -c '...'`): read-only
  commands are only pre-approved in this exact form. Git and file editing work fine from the Windows side.

## Fixing your environment

If a tool is missing, out of date or misconfigured, **fix the environment rather than working around it**, using
the setup steps in the [README](../README.md#getting-started). The aim is that the next session doesn't hit the same
problem.

- User-level fixes are pre-approved, so just do them and say what you did: `uv sync`, `uv tool install`,
  `uv run ansible-galaxy install -r requirements.yml`, `terraform init`, `brew install` on macOS, and fixing `PATH`
  in the user's shell profile.
- Anything that needs root (`sudo apt install`, `wsl -u root`) needs a password or confirmation. Give the human the
  exact command to run.
- Don't change versions pinned in the repo (`uv.lock`, `.terraform.lock.hcl`, `Chart.yaml`) to make something work
  locally. That's a change for a pull request.
- If the fix was a step missing from the README, add it to the README so it's documented for everyone.

## Rules for agents

- **Read-only commands are fine to run without asking** (`kubectl get`/`describe`/`logs`, `helm list`/`history`,
  `terraform plan`, PromQL/LogQL queries, etc.). **Ask before anything that changes state** (applying, deleting,
  scaling, restarting, `exec`, running playbooks, writing to Vault or GCS) and propose it rather than doing it.
- **Never run `ansible-playbook` or `terraform apply` against coven.** These deploy through CI on merge to `main`.
- **Never unseal or initialise Vault.** Only humans hold the unseal keys.
- **Don't run `./login.sh`.** It needs an interactive browser login. Ask the human to run it. Check whether credentials
  are already in place with `kubectl config current-context` and `kubectl auth can-i get pods -A`.
- **`./bootstrap-auth.sh` gives break-glass cluster-admin credentials.** Only use it with explicit permission when
  Vault or Keycloak is down.
- **Never print, log or commit secrets.** Don't read Terraform state files or `.vagrant/` private keys.
- If you make a temporary manual change as a mitigation, say clearly that the next CI run may revert it.

## Checks

There's no test suite. Before proposing a change:

- Terraform: `terraform fmt -check` and `terraform validate` in the affected folder (CI runs both, plus `plan`).
- Ansible: `uv run ansible-playbook --syntax-check -i testlab/inventory plays/configure-hosts.yml`, and the same for
  `plays/configure-cluster.yml`.
- To actually exercise a change, use the testlab (see the README). Confirm with a human before running it.

## Conventions

- Write docs and commit messages in British English, in a plain, direct style that matches the existing docs.
- Commit messages are a short sentence describing the change (e.g. "Replace Litestream with periodic k3s datastore
  snapshots"), with no type prefixes.
- Pin new Helm chart versions in `Chart.yaml` and read them with `lookup('helm_chart', '<n>')`.
- New hard-to-reverse decisions get an ADR, and incidents get a write-up, in the same PR as the change. Follow the
  templates and naming rules in each folder's README and add the new file to its index.
