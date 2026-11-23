# Working in public

This repository is public: everything committed, every pull request and comment, and every Actions log can be read by
anyone. This doc covers what must never go in, and the GitHub settings that keep CI's credentials safe. Those settings
live in GitHub, not in code, so if one is wrong, nothing fails: the protection quietly goes away. See
[ADR 005](./adr/005-publish-a-filtered-copy-of-this-repository-as-coven.md) for why we went public, and
[ADR 006](./adr/006-gate-ci-credentials-by-workflow-and-environment.md) and
[CI and its credentials](./cluster-overview.md#ci-and-its-credentials) for how the credential gate works.

## Never commit

Check this before opening a pull request, and before pasting anything into an issue or comment.

- **Secrets of any kind**: tokens, passwords, private keys, kubeconfigs, Vault tokens, `.env` files. Secrets live in
  Vault ([secrets.md](./secrets.md)). `.gitignore` covers Terraform state, plans and crash logs, but not everything.
- **Our home address**, or anything that pins it down: house number and street, postcode, coordinates or map links.
- **Personal email addresses** in commits. Use your GitHub noreply address for this repository:
  `git config user.email <id>+<login>@users.noreply.github.com`.
- **Unchecked output from the cluster**, pasted into issues, pull requests or incident write-ups. Check it for tokens,
  certificates' private keys and `Secret` data first.
- **In Terraform:** never `nonsensitive()`. Mark outputs `sensitive`. Get secrets into charts by reference
  (`existingSecret` and External Secrets) or write-only arguments, never as plain Helm values.
- **In workflows:** pass secrets to `run:` steps through `env:`, never `${{ secrets.* }}` or `${{ inputs.* }}` in the
  script itself (GitHub prints the script, and masking isn't reliable for multi-line values). Don't print config. Give
  Ansible tasks that handle secrets `no_log: true`, and don't add `-v` or `--diff` to Ansible in CI.

Some things look sensitive but are fine to publish, and were decided deliberately when we went public
([#124](https://github.com/omelette-gay/coven/issues/124)):

- host names, including the `gs` in home host names, LAN ranges and internal addresses
- public IP addresses, which are in DNS anyway
- GCP project IDs and numbers, the workload identity provider path, and the k3s CA certificate (public, not the key)

Secret scanning with push protection blocks the secret formats GitHub recognises, and the plan job scans plans with
gitleaks before posting them. Neither catches everything, so the checklist still applies.

## Repository settings

These are what the credential gate and the rest of the protection rely on. If you change one, update this doc in the
same pull request as any related change.

### Settings → Rules → Rulesets

| Ruleset | Target | Rules | Bypass list |
|---|---|---|---|
| `main` | Default branch | Restrict deletions, block force pushes, require a pull request before merging (merge commits, 0 approvals) | Empty, Renovate included |
| `no tag called main` | Tags matching `main` | Restrict creations | Empty |

Without the first, anyone who can push could get their code into `main`'s workflows, which are the only ones that get
credentials. Without the second, a tag called `main` could be confused with the branch.

### Settings → Environments

| Environment | Deployment branches and tags | Required reviewers | Other |
|---|---|---|---|
| `coven` | Selected: `main` only | None | WireGuard and SSH secrets for the host playbook |
| `coven-plan` | No restriction | None | |
| `coven-plan-review` | No restriction | Chris and Meg (either can approve) | **Allow administrators to bypass** must be off, as we're both admins |

### Settings → Actions → General

- **Approval for running fork pull request workflows from contributors:** require approval for all external
  contributors.
- **Workflow permissions:** read repository contents and packages. *Allow GitHub Actions to create and approve pull
  requests* is off.
- No workflow uses `pull_request_target`.

### Settings → Advanced Security

- Dependency graph and Dependabot alerts on. Dependabot version updates off, as Renovate does those.
- Secret scanning **and push protection** on.
- Private vulnerability reporting on (see [SECURITY.md](../SECURITY.md)).

### Organisation settings

- **GitHub Apps → Renovate → Repository access** includes `coven`. Renovate's plans land on `coven-plan-review`.
- **Actions → General:** nothing that overrides the repository's settings above (e.g. forcing write permissions for
  `GITHUB_TOKEN`).
- **People:** only Chris and Meg have write access to `coven`. Giving anyone else write access needs the allowlist in
  `tfplan-stack.yml` and ADR 006's notes on it revisited first.

## Checking the settings

Any of us can run these. Compare the output with the tables above.

```bash
R=repos/omelette-gay/coven
gh api $R/rulesets --jq '.[].id' | xargs -I{} gh api $R/rulesets/{} \
  --jq '{name, enforcement, include: .conditions.ref_name.include, bypass: .bypass_actors, rules: [.rules[].type]}'
gh api $R/environments --jq '.environments[] | {name, can_admins_bypass,
  rules: [.protection_rules[] | {type, reviewers: [.reviewers[]?.reviewer.login]}], branches: .deployment_branch_policy}'
gh api $R/actions/permissions/workflow
gh api $R/actions/permissions/fork-pr-contributor-approval
gh api $R --jq .security_and_analysis
```

## Checking the gate

The settings being right doesn't prove the gate works. These checks do, and they can only be done on `coven` itself,
as GitHub's runners can't reach the testlab's Vault. Use throwaway branches and pull requests, and close them
afterwards. Each of these must **fail to log in** to Vault and GCP:

- a pull request that changes `tfplan.yml` to call `./.github/workflows/tfplan-stack.yml` (its own copy)
- a pull request that calls the reusable workflow at its own branch instead of `@main`
- the plan steps copied straight into `tfplan.yml`
- a new workflow on a branch that sets `environment: coven-plan` and tries the Vault login
- a job with no environment that tries the Vault login

And these must work:

- a normal pull request from Chris or Meg runs on `coven-plan`, and the plan gets posted
- a run that isn't one of our pull requests (e.g. `workflow_dispatch`, or Renovate's) waits on `coven-plan-review`
  for approval
- a pull request from a fork by an account that isn't a collaborator waits for approval, and even once approved can't
  get credentials

If any refusal check *succeeds*, treat it as an incident: the gate isn't working, so stop approving plans and check
the bindings in [CI and its credentials](./cluster-overview.md#ci-and-its-credentials).
