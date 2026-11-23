# 006: Only `main`'s workflows get CI credentials, and Renovate's plans need approval

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-23 |
| **Related** | [ADR 005](./005-publish-a-filtered-copy-of-this-repository-as-coven.md) (the move to `coven`), [ADR 004](./004-bundle-renovate-updates-weekly.md) (Renovate bundles and the 3-day wait), [#844](https://github.com/omelette-gay/gitops/issues/844), #954 (actions pinned to commit SHAs) |

## Context

`tfplan.yml` runs on every pull request and logs in with the same credentials as apply:

- the Vault `gitops` role, with the `admin` policy (`path "*"`, sudo)
- cluster-admin through the Vault `github-gitops` role
- the GCP workload identity principal, which has `roles/editor`, `iam.workloadIdentityPoolAdmin` and the k3s token

The Vault roles and the GCP principal are only bound to the repository **name**. So any workflow on any branch can get
them, and so can any repository that takes the name later. A plan runs the pull request's own code with them:
`data "external"`, the providers and modules at the branch's versions, and the composite actions. Whoever can trigger a
plan effectively has admin over the cluster, Vault and GCP. Today that's Chris, Meg and Renovate. Pull requests from
forks can't get OIDC tokens.

**A read-only plan identity doesn't help here.** A plan has to read:

- **the Keycloak master admin credentials.** `vault_kv_secret_v2.keycloak_automation` is refreshed on every plan, and
  refreshing reads the secret. The Vault provider (5.13.0) doesn't allow `disable_read` with `data_json_wo`.
- **the backup service account key.** It's in Vault and in state.
- **every Kubernetes Secret.** Helm stores releases as Secrets, and RBAC can't limit reads to one type of Secret.

So a malicious "read-only" plan could get back to admin. **A plan is effectively admin, and so is approving one.**

**Two GitHub limits shape the design:**

- **An environment doesn't protect credentials on its own.** The OIDC `environment` claim only says which environment
  the job asked for. A pull request can edit the workflow to ask for any environment, and so can a new workflow on any
  branch.
- **On GitHub Free, rulesets and environments with required reviewers or branch rules only work in public
  repositories.** `gitops` can't use them while it's private.

The GCP CI identity also has `iam.workloadIdentityPoolAdmin` over the project that holds its own GitHub pool. So it can
change the conditions that decide who gets that identity. It only has that role so the platform stack can manage the
cluster's own pool (`coven/platform/workloadidentity.tf`), whose signing keys only change when the cluster is rebuilt.
IAM Conditions can't limit the role to one pool, because IAM resources don't expose their names to conditions.

## Decision

**This applies to `coven`, once it's public (ADR 005, step 6). `gitops` keeps its current setup until it's archived,
with actions pinned to commit SHAs (#954) and Renovate's 3-day wait as the only mitigations.**

1. **Protect `main` with a ruleset:** changes only through pull requests, no force-pushes or deletion, and no bypass
   for anyone, including the Renovate app. A second ruleset blocks creating a tag called `main`.
2. **Only workflows on `main` get credentials.** Each credentialed job is a reusable workflow, called at `@main`:

   | Reusable workflow | Environment | Called by |
   |---|---|---|
   | `tfplan-stack.yml` | `coven-plan` or `coven-plan-review`, chosen inside the workflow | `tfplan.yml`, on pull requests |
   | `tfapply-stack.yml` | `coven` | `tfapply.yml`, on push to `main` |
   | `configure-hosts.yml` | `coven` | `host_config.yml`, on push to `main` |

   Each has its own Vault role (all still admin, so audit logs show which one acted) and its own GCP principal, bound
   on `repository_id`, `job_workflow_ref` (`omelette-gay/coven/.github/workflows/<file>@refs/heads/main`) and the
   `environment` claim.

   **The binding is the control, not the `@main` in the callers.** GitHub sets `job_workflow_ref`, and a workflow can't
   change it. A pull request can edit `tfplan.yml` to call its own copy (`@refs/pull/N/merge`), a branch (`@refs/heads/x`)
   or a tag, or copy the steps straight into `tfplan.yml`, but each of those gives a different `job_workflow_ref`, so
   Vault and GCP refuse it. The same goes for a new workflow that asks for an environment. The `@main` in the callers
   only makes legitimate runs match the binding. The only way to get `@refs/heads/main` is to run code that's on
   `main`, and the ruleset makes sure that only happens through a merged pull request.
3. **The plan workflow picks its environment from the event, never from inputs.** It's `coven-plan` only when the event
   is a pull request from this repository, and both the pull request's author and the user who triggered the run are
   Chris or Meg (matched on user ID). Everything else, including Renovate, anyone given write access later and any
   other event, gets `coven-plan-review`, which needs Chris or Meg to approve it.
4. **`coven` only allows `main`.** Its branch rule is checked against the run's ref, so a pull request can't use it.
5. **CI can't change any workload identity pool.** The cluster's pool and provider move from `platform` to `bootstrap`,
   next to the GitHub pool. Like the IAM grants already in `bootstrap`, they're applied locally by a project owner, and
   CI's apply then finds nothing to change. CI loses `iam.workloadIdentityPoolAdmin` and gets
   `iam.workloadIdentityPoolViewer`, so its plans can still read both pools and show drift.
6. **The pull request comment is posted by a separate job without cloud credentials.** The plan text in the artifact is
   treated as untrusted text: it's only ever posted, never run or read into variables. (The comment job never moves to
   `workflow_run`.)
7. **The reusable workflows stay thin:** check out the code, choose the environment, call a composite action, upload the
   artifact. Everything else goes in the composite actions (`.github/actions/`), which run from the pull request's
   checkout, so pull requests test it. `lint.yml`, which has no credentials, runs `actionlint` and `zizmor` on every
   workflow change, including changes to the reusable workflows.

## Alternatives considered

**A read-only plan identity.** Rejected for the reasons in Context. To make it work, we'd first need to move the
Keycloak admin credentials and the backup key out of what plans refresh, and stop plans needing every Secret. Worth
revisiting if anyone else gets write access.

**Environments without binding on `job_workflow_ref`.** Anyone who can push a branch could ask for the unreviewed
environment. That's the version of this ADR an adversarial review rejected.

**Approval for every plan, including ours.** One environment, but we'd be approving our own pull requests several times a
day, when we can already merge them.

**Skip plans for Renovate pull requests.** No credentials for Renovate at all, but we'd lose the plan that shows what a
chart update changes, which is the main reason to review it.

**Move the GitHub pool into its own GCP project, in a separate owner-only stack.** CI wouldn't even need read access,
but it adds a fourth stack and a second project to look after, for resources that rarely change.

**Keep CI's pool admin, and limit it to the cluster's pool with an IAM condition.** Not possible: IAM Conditions can't
see the names of IAM resources.

**Pay for GitHub Pro or Team so `gitops` can use rulesets and environments now.** Team still doesn't give required
reviewers on private repositories, and we're moving to a public repository anyway.

## Consequences

- **Approving a plan gives admin to the code in that pull request,** and admin can make itself permanent: new Vault
  tokens and roles, long-lived Kubernetes service account tokens. Approve only after looking at what changed,
  especially provider, module, chart and action versions. A bad approval means rotating Vault, Kubernetes, GCP,
  Hetzner and Keycloak credentials.
- **The allowlist checks who triggered the run, not who wrote every commit.** If someone else's commits end up on
  Chris's or Meg's branch, they run without approval. That's fine while only the two of us can push. Revisit before
  giving anyone else write access.
- **Renovate is part of the threat model.** The hosted app can push branches and edit workflows. The ruleset stops it
  changing `main`, its plans need approval, and its pull requests can't make a branch copy of a workflow get
  credentials. Its pull requests still need one of us to merge them.
- Renovate's plans wait for a click, about one per weekly bundle (ADR 004), plus one per separate update and rebase.
  The rebases are what's most likely to get approved without looking.
- **A change to `tfplan-stack.yml` itself isn't run by its own pull request**, because plans always run `main`'s copy. It
  first runs on the next pull request after merging, and a broken plan fails without changing anything.
  `tfapply-stack.yml` and `configure-hosts.yml` first run when they deploy, as they do today. Everything else in a pull
  request (the composite actions, Terraform code, providers, and the workflows without credentials) runs from the pull
  request, so most action updates are still tested, as the important actions live in the composite actions. A pull
  request can change *what* runs with the credentials, as it already can through the Terraform code, but not *whether*
  it gets them: the environment is chosen before any of its steps run.
- The rulesets and environments are set in the repository settings, not in code. If they're misconfigured, for example
  `coven-plan-review` with no reviewers, the gate quietly disappears. The setup, and how to check it, has to be
  written up in the cluster docs.
- **Worth considering:** managing the rulesets and environments in Terraform with the GitHub provider, in `bootstrap`
  and applied by an owner like the workload identity pools, so drift shows up in plans. They must not be something CI
  can apply, as CI would then be managing its own gate.
- Changes to either workload identity pool (in practice, the cluster's signing keys after a rebuild) need a project owner
  to apply `bootstrap` locally before merging, or CI's apply fails. Moving the cluster's pool between stacks needs a
  `removed` block in `platform` and an `import` block in `bootstrap`.
- Removing pool admin protects the gate, not everything else. CI still has `roles/editor`, which can create service
  account keys, so a bad approval can still leave lasting access that way. Unlike a loosened pool condition, extra keys
  show up in `gcloud iam service-accounts keys list`.
- **The refusals can only be checked on coven.** GitHub's runners can't reach the testlab's Vault, so the testlab only
  checks the Terraform side: that the new Vault roles apply. Straight after Actions is turned on for `coven`, we check
  from throwaway pull requests and branches that Vault and GCP refuse a token from the pull request's own copy of a
  workflow, from a branch, from steps copied into the caller and from a job with no environment, and that a normal pull
  request from one of us gets a plan while a non-pull-request run waits for approval. A tag called `main` can't be
  created, as the tag ruleset blocks it.
- **Worth adding later:** an alert on Vault audit log writes to `sys/auth*`, `sys/policy*`, `auth/github/role/*` and
  `auth/token/create*` that don't come from an apply run.
