# 003: Update dependencies within version ranges through lock files, and group non-major Helm chart updates

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-05 |
| **Related** | [Renovate configuration](../../.github/renovate.json) |

## Context

Renovate keeps our dependencies up to date by raising pull requests, and every merge to `main` deploys, as it runs
the Ansible playbook and applies Terraform. So each Renovate pull request we merge is a deploy, and we want each one
to be clear about how risky it is, without creating so many that they become noise.

In November 2026 we noticed `uv.lock` had fallen behind: Ansible was locked at 14.3.1 when 14.6.0 was out, and every
other Python dependency was locked at exactly the lower bound in `pyproject.toml`. The cause was the
`:preserveSemverRanges` preset, which sets Renovate's `rangeStrategy` to `replace`. That only does something when a
new version falls outside the range, and our ranges were all `>=` with no upper bound, so nothing ever fell outside
them and the lock file was never updated.

Renovate's default `rangeStrategy` is `auto`, but what that means depends on the manager. It becomes
`update-lockfile` for managers that implement updating a locked dependency (`terraform` does), and `replace` for the
rest, including `pep621`, which we use for `pyproject.toml` and `uv.lock`.

The lock files we have are `uv.lock` and the `.terraform.lock.hcl` in each Terraform root module (`coven/` and
`testlab/`, each with bootstrap, platform and apps). The modules in `tfmodules/` don't have lock files, as Terraform
only uses the root module's.

Helm chart versions don't reliably follow semantic versioning, so grouping "non-major" chart updates isn't safe for
every chart:

- Renovate classifies `0.29.1` to `0.30.0` as a minor update, but under semantic versioning a 0.x minor release can
  break things.
- Some charts use calendar versions. `mariadb-operator` is versioned year.month, so each release looks like a minor
  update, but they change CRDs and behaviour and are meant to be upgraded in order.
- Some charts wrap an application that is still 0.x. The external-dns chart went from 1.21 to 1.22 in a minor
  release that made `policy` required and changed the default annotation prefix, which could delete DNS records.
- Some charts stay on 1.x, and their minor releases are the significant upgrades. Longhorn minor releases have their
  own upgrade notes and can only be upgraded one minor version at a time, and cert-manager minor releases remove
  deprecated APIs.

## Decision

**Use version ranges, and let lock files hold the exact versions.**

- In `pyproject.toml`, each dependency is `>=` the oldest version we've tested and `<` its next major version, for
  example `ansible>=14.3.1,<15`. `requires-python` has no upper bound.
- In the Terraform root modules, providers use `~> X.Y` (for example `~> 3.5`, which allows anything below 4.0). 0.x
  providers use `~> 0.Y.0`, which only allows patch releases. Modules in `tfmodules/` keep their `>=` minimums.
- CI uses the lock files exactly as committed: `uv sync --locked` for Python, and `terraform init -lockfile=readonly`
  for Terraform.

**Renovate uses `rangeStrategy: update-lockfile` for `pep621` and `terraform`.** A new version inside the range gets
a pull request that only changes the lock file. A new version outside the range (a new major version) gets a pull
request that also changes the range, so it's clearly a bigger change that needs testing.

**Lock file maintenance is enabled**, on Renovate's default weekly schedule. It's the only thing that updates
transitive Python dependencies, and it also refreshes the Terraform lock files.

**Minor and patch updates to Helm charts, whether in `Chart.yaml` or in Terraform `helm_release` resources, are
grouped into one weekly pull request.** Major updates still get their own pull requests, as soon as they're released.
A chart is left out of the group, and gets its own pull request for every update, if any of these apply:

1. It is still 0.x. This is handled automatically, by only grouping charts at 1.0.0 or above.
2. It doesn't use semantic versioning, for example it uses calendar versions.
3. It wraps an application that is still 0.x, or where minor releases are significant upgrades.

The charts excluded under 2 to 4 are listed in `renovate.json`. When a chart breaks something in a minor release, add
it to that list, and say so in the incident write-up. `mariadb-operator` and `mariadb-operator-crds` are also always
updated together, as the CRDs must match the operator.

**We accept some things that float without a lock:**

- GitHub Actions are referenced by major version tag (`@v4`), not pinned to a commit. They're widely used actions, or
  our own (`vault-k8s-login-action`), and pinning to commits would add a pull request for every release.
- CI installs the latest Terraform CLI and uv on each run. A new Terraform version that changes a plan unexpectedly
  would be visible when the plan is reviewed.
- Ansible Galaxy has no lock file, so although the collections in `requirements.yml` are pinned exactly, any
  dependencies they declare are resolved when they're installed.

Helm chart versions, Galaxy collections and the container images managed by the regex managers are pinned to exact
versions, so they're unaffected. Operating system packages (updated by `dnf-automatic`) and the self-deploying apps
(updated in their own repositories) are out of scope.

## Alternatives considered

**Keep `>=` ranges with `update-lockfile`.** This fixes the lock file, but a new major version would only update the
lock file too, so a major upgrade would look the same as a patch.

**Pin exact versions everywhere.** This is what we had in Terraform, and it works, but every patch release changes the
configuration (in up to six root modules for a provider), and it doesn't distinguish a patch from a major upgrade. It
also doesn't help with transitive Python dependencies, which still need lock file maintenance.

**Rely on `rangeStrategy: auto`.** It gives `update-lockfile` for Terraform, but `replace` for `pep621`, which is the
behaviour that caused the problem. Setting it explicitly also protects us if Renovate's defaults change, as they have
before.

**`~=X.Y` instead of `>=X.Y.Z,<X+1` in `pyproject.toml`.** Both work with Renovate. The compound form records the
oldest version we've actually tested, and Renovate raises that minimum when it bumps the range for a new major.

**Group every non-major Helm chart update.** Less noise, but it would bundle the releases that most often break things
(see Context) into a pull request that looks routine.

**Run lock file maintenance daily.** Each merge runs the playbook against both nodes and applies Terraform, and each
update to the pull request runs a Terraform plan. That's a lot of GitHub Actions minutes and deploys for mostly
transitive patch updates.

**Pin GitHub Actions to commits, and pin the Terraform CLI and uv versions.** These would close the gaps listed above,
but add noise we don't think is worth it for these tools.

**Merge Renovate pull requests automatically.** Not adopted, as every merge deploys to coven.

## Consequences

- Renovate raises two kinds of pull request for Python and Terraform: ones that only change a lock file (a new
  version in range, usually low risk), and ones that change a version range (a new major version, so read the
  changelog and test it).
- A pull request that only changes `uv.lock` still changes the Ansible and Python packages used by the next deploy.
  When looking for what changed before an incident, check the history of the lock files, not just `pyproject.toml` and
  the `.tf` files.
- Several chart updates can now arrive in one "Helm charts (non-major)" pull request, which is harder to bisect if an
  alert follows. The pull request lists every chart and version it changes.
- A patch to a grouped chart can wait up to a week. To get it sooner, tick it on the Dependency Dashboard.
- The list of excluded charts in `renovate.json` needs maintaining, using the criteria above.
- The `kubernetes` Python client's major version follows Kubernetes releases, so it will get a pull request that bumps
  its range every few months.
- After editing a version range by hand, regenerate the lock file (`uv lock`, or `terraform init` in each affected root
  module) and commit it, or CI will fail. The Terraform plan on pull requests only covers the `coven/` stacks, so the
  `testlab/` lock files aren't checked until someone uses the testlab.
