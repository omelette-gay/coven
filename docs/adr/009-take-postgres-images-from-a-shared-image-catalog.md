# 009: Take every PostgreSQL image from a shared ClusterImageCatalog

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-26 |
| **Related** | #128; [ADR 002](./002-three-stack-terraform-for-cluster-configuration.md); [ADR 004](./004-bundle-renovate-updates-weekly.md); [cnpg module](../../tfmodules/cnpg/) |

## Context

Every PostgreSQL database on the cluster is a CloudNativePG (CNPG) cluster, and nothing ever updated their images, so
Trivy reported large numbers of vulnerabilities in them. In November 2026:

- Keycloak, Home Assistant and the wedding site ran `ghcr.io/cloudnative-pg/postgresql:16`, the `cluster` chart's
  default. Bare tags like `16` are legacy rolling tags from before the minimal, standard and system flavours, are based
  on Debian bullseye, and are being phased out upstream (cloudnative-pg/postgres-containers#285). With
  `imagePullPolicy: IfNotPresent`, a rolling tag never refreshes on a node that already has it.
- GlitchTip set no image, so it got the operator's default, the `system` flavour. That bundles Barman Cloud, which we
  don't need because we back up with the barman-cloud plugin, and it's deprecated upstream. It only changed when the
  operator was upgraded.
- Vikunja pinned a minimal image by hand, which nothing updated either.

Upstream publishes `ClusterImageCatalog` manifests in
[cloudnative-pg/artifacts](https://github.com/cloudnative-pg/artifacts/tree/main/image-catalogs): one image per
PostgreSQL major, pinned by digest, rebuilt about weekly. A CNPG cluster can reference a catalog and a major version
instead of an image, and the operator rolls the cluster (restarting the standbys, then switching over) whenever the
catalog's image for that major changes.

Every database on the cluster uses `C` collation, so moving between flavours or Debian releases doesn't change sort
order and needs no `REINDEX`.

## Decision

- The bootstrap stack installs one `ClusterImageCatalog`, named `postgresql`, from upstream's
  `catalog-minimal-trixie.yaml` at a pinned commit of `cloudnative-pg/artifacts`. It's made through a small local chart,
  because its CRD comes from the operator in the same stack (see ADR 002).
- Renovate updates the commit, bundled into the weekly Platform pull request (see ADR 004), so every image change is a
  reviewed pull request and appears in `git log`.
- Every PostgreSQL cluster, ours and the self-deploying apps', references the catalog with `cluster.imageCatalogRef`
  (kind `ClusterImageCatalog`, name `postgresql`) and sets only `version.postgresql` to its major version.
- The operator waits `CLUSTERS_ROLLOUT_DELAY` between clusters and `INSTANCES_ROLLOUT_DELAY` between instances, so a
  catalog update doesn't restart every database at once.
- The catalog's name is chosen in each environment's root module and passed to everything that uses it, like the
  Longhorn backup job's name. It names the role, not the flavour or Debian release, so changing those doesn't mean
  changing every app.

## Alternatives considered

**Pin each cluster's `imageName` and let Renovate update them.** Every database would need its own Renovate rule, and the
self-deploying apps would each need their own config. The tags (`18.7-202611230809-minimal-trixie`) also need a custom
versioning scheme to compare.

**A CronJob that applies upstream's latest catalog.** Images would change without a pull request or any record in the
repo, so a broken image couldn't be traced back to a change.

**Write the catalog ourselves in Terraform.** We'd have to track each major's digest ourselves, which is what upstream's
catalog already does.

**The `standard` or `system` flavours.** We don't need the extra locales (every database uses `C`) or Barman Cloud (we use
the plugin). Minimal images are smaller and have fewer packages to have vulnerabilities in.

## Consequences

- Each catalog update rolls every PostgreSQL cluster, with a switchover each. With the delays, a weekly update takes
  around half an hour to work through the cluster. Each switchover drops the app's database connections: on the
  testlab, Keycloak failed one readiness probe and recovered by itself without restarting.
- Upstream drops a major from the catalog some time after it's end of life. A cluster on a major that's no longer in the
  catalog stops being reconciled, so databases have to be upgraded before then. Changing `version.postgresql` to a new
  major upgrades the database in place.
- A database that really needs a specific minor version can still opt out with a digest-pinned `cluster.imageName`, but
  then nothing updates it.
- Planning the bootstrap stack fetches the catalog from GitHub, so a GitHub outage blocks bootstrap plans.
- Renaming the catalog means changing every app that references it, including the self-deploying apps' repos.
