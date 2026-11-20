# 004: Bundle non-major Renovate updates into weekly pull requests by area

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-20 |
| **Related** | Supersedes the Helm chart grouping in [ADR 003](./003-update-dependencies-within-ranges-through-lock-files.md); [Renovate configuration](../../.github/renovate.json) |

## Context

Every Renovate pull request we merge is a deploy (see [ADR 003](./003-update-dependencies-within-ranges-through-lock-files.md)).
ADR 003 grouped minor and patch Helm chart updates into one weekly pull request, which stopped the worst of the noise
from `kube-prometheus-stack` and `loki`. Everything else still got its own pull request as soon as it was released.

In the 15 days after ADR 003, Renovate opened about 27 pull requests. Most were small and low risk: in-range lock file
updates for Python packages and Terraform providers (the `google` provider releases weekly), Galaxy collections, game
server images, GitHub Actions (`setup-uv` alone opened three in eight days), and 0.x chart patches. Reviewing and
deploying each one separately was more work than the risk justified.

Some releases are also replaced within a day or two, for example `loki` 19.0.0, 19.0.2 and 19.0.3 all came out on
21 October 2026, and a release that turns out to be broken is usually fixed or withdrawn within a few days.

Factorio clients update themselves to the latest stable release, and a client can only join a server running the same
version, so the Factorio server has to be updated as soon as a release is out.

ADR 003's reasons for keeping some Helm charts out of a group (0.x charts, calendar versions, and charts whose minor
releases are significant upgrades) still apply. They only concern minor releases, not patches.

## Decision

**Non-major updates are bundled into up to four pull requests, raised before 6am on Mondays:**

| Bundle | Contains |
|---|---|
| **Platform (non-major)** | Helm chart minor and patch updates, and the container images used by the platform (`rustfs/rc`, and patch releases of the Hetzner external-dns webhook) |
| **Apps (non-major)** | Charts and images for the apps this repo deploys, such as the game servers. Self-deploying apps are updated in their own repositories |
| **Tooling (non-major)** | Python packages (lock file only) and Galaxy collections used by Ansible, in-range Terraform provider updates, Terraform CLI patch releases, and GitHub Actions (including the Helm CLI version used in CI) |
| **Lock file maintenance** | Unchanged from ADR 003 |

**Some updates get their own pull request, as soon as they pass the minimum release age:**

1. Major updates.
2. Minor updates to anything still 0.x, as a 0.x minor release can break things. Patches to 0.x charts and images are
   bundled. `rustfs/rc` is an exception, as it's only the client used by setup jobs.
3. Minor updates to the charts excluded in ADR 003 (`cert-manager`, `external-dns`, `longhorn`), and to the Hetzner
   external-dns webhook, as it manages DNS records.
4. `mariadb-operator` and `mariadb-operator-crds`, which are versioned by date and always updated together.
5. `xanmanning.k3s`, as it installs k3s on the nodes.
6. Factorio's server image, as above.

**Every update waits 3 days after release** (`minimumReleaseAge`) before Renovate raises or updates a pull request,
except the Factorio image. Updates whose source doesn't publish release dates are not held back.

**Apps are listed explicitly**, by chart and image name, in the Apps rules in `renovate.json`. Anything not listed falls
into Platform, or gets its own pull request. When adding an app, add its charts and images to both Apps rules, and
when a chart or image breaks something in a minor release, add it to the relevant exclusion list (and say so in the
incident write-up).

## Alternatives considered

**Keep ADR 003's grouping.** Too many pull requests for low-risk changes, which is the problem this solves.

**One bundle per area of tooling (Ansible, Terraform, CI).** Easier to bisect, but three pull requests a week for
changes that are almost always routine. The Tooling bundle is the first one to split again if it causes trouble.

**Find apps by folder, by moving app modules into `tfmodules/apps/`.** New apps would join the bundle automatically,
but it means restructuring `tfmodules/` for the sake of Renovate. An app that's missing from the list ends up in the
Platform bundle, which is reviewed more carefully, so forgetting to add one is safe.

**Drop the separate in-range Python and Terraform updates, and rely on lock file maintenance.** One fewer pull request,
but lock file maintenance pull requests don't include release notes.

**Group game servers with the platform images.** Fewer pull requests, but the Apps bundle can be reviewed lightly
because nothing important breaks, which wouldn't be true with the external-dns webhook in it.

**Merge Renovate pull requests automatically.** Still not adopted, as every merge deploys to coven.

## Consequences

- Most weeks bring up to four pull requests on a Monday, plus individual pull requests for majors and the exceptions
  above. Bundles only appear when something in them has an update.
- A bundle is harder to bisect than single updates. Each one lists every package and version it changes.
- A patch can wait up to a week plus 3 days. To get one sooner, tick it on the Dependency Dashboard.
- The Tooling and lock file maintenance pull requests both change `uv.lock` and the Terraform lock files, so whichever
  is merged second will need rebasing, which Renovate does itself.
- The list of apps and the exclusion lists in `renovate.json` need keeping up to date.
- The 3-day wait relies on Renovate getting release dates from each source. If it doesn't, the update isn't held back.
