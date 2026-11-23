# 005: Publish a filtered copy of this repository as a new public repository, `coven`

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-11-23 |
| **Related** | [#844](https://github.com/omelette-gay/gitops/issues/844) (making the repo public), [#843](https://github.com/omelette-gay/gitops/issues/843) (self-hosted runners, not planned), [#561](https://github.com/omelette-gay/gitops/issues/561) (secret rotation during the Terraform migration) |

## Context

We keep running out of free GitHub Actions minutes. Standard GitHub-hosted runners are free for public repositories, and
we use Coven for professional development, so a public repository that shows how we work is useful in its own right.
#843 (self-hosted runners with fallback) was closed in favour of going public.

What has to stay private:

- **Our home address.** It has been in the tree since December 2024 (`096d169`), so almost all of the 1,822 commits on
  `main` contain it. It's also in issue and comment text, including #844 itself.
- **Terraform state.** `cloud-resources/terraform.tfstate` and its backup were committed nine times between August and
  October 2025. State holds every attribute in plaintext, including secrets, and also things that can't be rotated,
  such as personal email addresses and the billing account ID.

We're not worried about secrets in history as long as they're rotated, but the state files are being removed anyway
(see Decision).

We've accepted that the `gs` in host names is vague enough to publish, because it's already in the router's reverse
DNS.

Rewriting this repository's history in place would change almost every commit. GitHub keeps the old commits reachable
through `refs/pull/*`, which we can't force-push, and there are over 700 merged pull requests. Only GitHub Support can
purge those, and we can't fully check that they have. Old issue and comment revisions also stay in their edit history
until each one is deleted. If we miss one, it's public for good.

## Decision

**Keep `omelette-gay/gitops` private as the archive, and publish a filtered copy of its history as a new repository,
`omelette-gay/coven`.**

1. Fix the CI credentials first (separate plan and apply identities, apply bound to `main` and the `coven`
   environment), because they matter whichever repository CI runs in.
2. On a local mirror clone, use `git filter-repo` to:
   - remove the Terraform state and plan files
   - replace the home address
   - rewrite `#N` references in commit messages to `omelette-gay/gitops#N`, so they don't link to unrelated issues in
     the new repository
   - optionally change author emails with a mailmap
3. Check the result locally, before it's pushed anywhere: gitleaks over the full history, and greps for the address
   and any other values on the list. Keep the redaction list outside the repository and delete it afterwards.
4. Create `coven` as a **private** repository and push the filtered history. It has no pull request refs, workflow
   runs or comments to clean up.
5. Set up CI trust for `coven` (Vault JWT roles and GCP workload identity), bound on `repository_id` rather than the
   repository name, plus environments, secrets, branch rules, Renovate, and references from the self-deploying app
   repositories.
6. Transfer the issues worth keeping from `gitops` to `coven` after checking their text and edit history. Issues can't
   be transferred from a private repository to a public one, so this happens while `coven` is still private.
7. Apply the repository settings from #844 (secret scanning and push protection, approval for fork pull requests,
   read-only default `GITHUB_TOKEN`, `SECURITY.md`), then make `coven` public.
8. Archive `gitops`.

Every secret found in history is still rotated, as decided in #844. With this approach, rotation is good hygiene
rather than something that blocks going public.

## Alternatives considered

**Rewrite this repository's history in place.** Keeps the issues, pull requests, links and name. Rejected for the
reasons in Context: it depends on GitHub Support purging hundreds of pull request refs, which we can't fully verify;
edit histories have to be cleaned one by one; and commit SHAs quoted in issues and docs break anyway.

**A fresh repository with no history.** The safest option, but it loses `git log` and `git blame`, which are a big
part of what makes the repository worth showing. Filtering the history locally and checking it before the first push
gives almost the same safety.

**Rename this repository to `gitops-legacy` and reuse the name `gitops` for the new one.** GitHub redirects a renamed
repository's old URL, including `git push`, until a new repository takes the name. Then every old clone would push
unfiltered history to the public repository by default. It would also break the redirects for links to old issues and
pull requests, and the commit message references above couldn't point at the archive. `coven` also describes the
repository better than `gitops`.

**Self-hosted runners on Coven (#843).** A lot of moving parts (ARC, a status reporter, a GCP watchdog), and falling
back to GitHub-hosted runners does nothing in the months it's needed, when the minutes have run out.

**Stay private and pay for minutes.** Cheap, and still an option as a stopgap, but it doesn't give us a public
repository.

## Consequences

- Pull requests and their discussion stay in the private archive. Merge commits, issues and ADRs carry most of the
  reasoning.
- Transferred issues get new numbers. `#N` references in issue text aren't rewritten, and links to old commits and
  pull requests only work for us.
- The Vault, GCP and app repository configuration that refers to `omelette-gay/gitops` has to move to `coven`. Binding
  on `repository_id` means that if a repository name is reused later, it doesn't inherit trust.
- Everything we commit, and everything CI prints or posts, is public from then on. We need a "never commit" checklist
  in the docs, and to decide what the Terraform plan comments show.
- Clones of `gitops` must never be pushed to `coven`. Both of us start from a fresh clone of `coven`.
