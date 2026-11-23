# The `minio/mc` image became unpullable, which failed the platform apply and left GlitchTip half-migrated

| | |
|---|---|
| **Status** | Resolved |
| **Detected** | 2026-11-14 14:24 UTC, by the failed `tfapply.yml` run. `KubeJobNotCompleted` also fired for the stuck Job |
| **Impact started** | 2026-11-14 14:13 UTC (the apply deleted GlitchTip's old Secrets) |
| **Resolved** | 2026-11-16 ~11:00 UTC |
| **Severity** | Minor (GlitchTip is an internal error tracker; object storage was inaccessible but no data was lost) |
| **Alerts** | `KubeJobNotCompleted` for `glitchtip/create-glitchtip-bucket-glitchtip` |

## Summary

Merging [PR omelette-gay/gitops#911](https://github.com/omelette-gay/gitops/pull/911) ("Keep generated secrets out of Terraform state")
renamed the Secrets holding GlitchTip's object-store credentials, which forced Terraform to replace the one-off Job that
creates the RustFS bucket. The replacement Job's image, `minio/mc:latest`, can no longer be pulled from Docker Hub, so
the Job never completed, the `platform` apply failed, and GlitchTip's Helm release was never updated to use the new
Secrets. The RustFS data volume was not touched.

## Impact

- The `platform` stack's apply on `main` failed at 14:24 UTC on 2026-11-14 and has not been re-run. Nothing after the
  GlitchTip module in that stack was applied.
- The Job `create-glitchtip-bucket-glitchtip` has been in `ImagePullBackOff` since, and keeps retrying.
- GlitchTip's Helm release still references the deleted Secrets `glitchtip-secrets` and
  `glitchtip-object-store-credentials`. One `glitchtip-web` pod is in `CreateContainerConfigError`
  (`secret "glitchtip-secrets" not found`). The other is still running only because it started before the Secret was
  deleted, and will fail the same way if it restarts.
- RustFS has the new credentials, but the running web pod still has the old ones. RustFS logs `InvalidAccessKeyId`
  rejections, so GlitchTip is probably failing to read or write object storage. Which clients send the rejected key,
  and what GlitchTip stores there, hasn't been confirmed.
- The object store itself was not recreated: `glitchtip-rustfs-data` is still the original 87-day-old PVC.

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-11-14 14:12 | PR omelette-gay/gitops#911 merged to `main` |
| 2026-11-14 14:13 | `tfapply.yml` plans 14 to add, 2 to change, 4 to destroy. The old Secrets and the `configure_oidc` and bucket Jobs are destroyed. New Vault secrets, ExternalSecrets and the new bucket Job are created |
| 2026-11-14 14:14 | New bucket Job created. Its pod goes into `ImagePullBackOff` |
| 2026-11-14 14:24 | Terraform gives up waiting: `job: glitchtip/create-glitchtip-bucket-glitchtip is not in complete state`. Apply fails |
| 2026-11-16 | Stuck-job alert investigated. Docker Hub found to be refusing `minio/mc` (see below) |
| 2026-11-16 ~10:50 | [PR omelette-gay/gitops#923](https://github.com/omelette-gay/gitops/pull/923) merged: replaces `minio/mc` with `rustfs/rc`. Stuck GlitchTip Job deleted manually |
| 2026-11-16 ~11:00 | Terraform apply completes. Helm release updated to revision 5. Both GlitchTip web pods running, RustFS accepting writes with the new credentials. `KubeJobNotCompleted` resolves |
| 2026-11-16 ~11:10 | Ansible `configure-cluster.yml` fails: the Loki bucket-creation Jobs in `monitoring` still have `minio/mc:latest` in their spec, and `spec.template` is immutable on a Job. Kubernetes rejects the patch |
| 2026-11-16 ~11:20 | Old Loki bucket Jobs deleted manually. Ansible re-run recreates them with `rustfs/rc` and they complete |

## Root cause

Two things combined:

1. **`minio/mc` is no longer available from any registry.** Docker Hub returns `401` for the `latest` manifest of both
   `minio/mc` and `minio/minio`, even with a valid anonymous pull token, and `hub.docker.com/v2/repositories/minio/mc/`
   returns `404`. Quay.io returns the same. Other public images (`library/busybox`) pull fine. The repositories have
   been removed or made private, likely as part of MinIO's licence change. The same Job was created successfully in
   August, so the image was pullable then.
2. **The change was a Job replacement.** `kubernetes_job_v1.bucket` has the credentials Secret name in its spec, so
   renaming the Secret forced a replacement. That is the first time in a while that something had to pull the image
   again (it is `:latest`, so the pull policy is `Always`). Nothing warned us that the image had gone.

The Job also does nothing useful here: the `glitchtip` bucket already exists on the persisted volume, and `mc mb
--ignore-existing` was a no-op. A failure to pull its image still failed the whole apply.

## How we found it

```
gh run view 43603668234 --repo omelette-gay/gitops --log-failed
kubectl get jobs,pods -n glitchtip
kubectl get pod create-glitchtip-bucket-glitchtip-4hq2w -n glitchtip -o jsonpath='{.status.containerStatuses[0].state}'
```

The last command gave: `failed to resolve reference "docker.io/minio/mc:latest": pull access denied, repository does
not exist or may require authorization: server message: insufficient_scope: authorization failed`. This is a registry
refusal, not a node or network problem: the node is healthy (no pressure conditions, no taints), and the only pod on
the cluster using `minio/mc` is this one.

To check Docker Hub from outside the cluster, fetch an anonymous pull token from
`https://auth.docker.io/token?service=registry.docker.io&scope=repository:minio/mc:pull`, then request
`https://registry-1.docker.io/v2/minio/mc/manifests/latest` with it. `minio/mc` and `minio/minio` returned `401`, while
`library/busybox` returned `200`.

## Resolution

Replace `minio/mc:latest` with [`rustfs/rc`](https://hub.docker.com/r/rustfs/rc), RustFS's own S3 CLI client.
The `rc` command is a drop-in replacement: `rc alias set` replaces `mc alias set`, and `rc bucket create
--ignore-existing` replaces `mc mb --ignore-existing`. The image is pinned to `v0.1.37` and tracked by Renovate
in the Terraform module.

After merging, the stuck GlitchTip Job was deleted manually and the Terraform re-run completed successfully. The Helm
release updated to revision 5, both GlitchTip web pods came up with the new Secret references, and RustFS stopped
logging `InvalidAccessKeyId` rejections. GlitchTip stores performance span data and cold storage in RustFS; the
existing `glitchtip` bucket and its data were untouched throughout.

The Ansible `configure-cluster.yml` run then failed because Loki's three bucket-creation Jobs in `monitoring` still had
`minio/mc:latest` in their spec. A Job's `spec.template` is immutable, so Ansible's `kubernetes.core.k8s` couldn't
patch them. Deleting the old Jobs and re-running Ansible fixed it — they were recreated with `rustfs/rc` and completed
immediately.

## Lessons

- **Went well:** the Secrets migration itself worked. The Vault secrets, ExternalSecrets and SecretStores were created
  and synced, and the RustFS data was never at risk.
- **Didn't go well:** the plan showed the Job being replaced, but nothing flagged that this needed a fresh image pull.
  A `:latest` tag meant we couldn't tell the image had changed or vanished until something pulled it. A failed apply
  also left the old Secrets deleted but the Helm release still pointing at them.
- **Lucky:** the bucket Job was a no-op, and RustFS keeps its data on a PVC separate from the credentials.
- **Didn't anticipate:** changing the image in the Ansible role required manually deleting the existing completed Jobs,
  because `spec.template` is immutable. Terraform handles this with destroy-and-recreate, but Ansible's
  `kubernetes.core.k8s` tries to patch. This is a one-off since the image won't change again before Loki moves to
  Terraform.

## Follow-up actions

- [x] Decide on and pin a replacement for `minio/mc:latest` (Terraform module and Ansible role) — `rustfs/rc:v0.1.37`
- [x] Unblock the apply, and confirm GlitchTip's web pods and object storage recover — done, both pods running, RustFS writing normally
- [x] Confirm what GlitchTip stores in RustFS and whether anything was lost while the credentials mismatched — performance spans and cold storage; the bucket and its data were untouched, though writes would have failed while the credential mismatch was live
- [x] Confirm which alert fired, and when — `KubeJobNotCompleted`, now resolved
- [x] Check the other users of `tfmodules/object-store` — Loki's bucket Jobs (Ansible-managed) also needed manual deletion; Minecraft had no outstanding Jobs
- [x] Delete old Loki bucket Jobs so Ansible can recreate them with `rustfs/rc`
- [x] Consider whether the bucket Job should be able to fail an apply, or should be ordered so the Helm release is
      updated first when Secrets are renamed — not actionable: the Job already runs after the Helm release
      (`depends_on`), and the dependency graph can't be reordered to avoid this. The real fix is the pinned image
      tracked by Renovate, which prevents a vanished upstream from surprising us again

## References

- [PR omelette-gay/gitops#911: Keep generated secrets out of Terraform state](https://github.com/omelette-gay/gitops/pull/911)
- [Failed `tfapply.yml` run](https://github.com/omelette-gay/gitops/actions/runs/43603668234)
- [PR omelette-gay/gitops#923: Replace `minio/mc` with `rustfs/rc`](https://github.com/omelette-gay/gitops/pull/923)
- [Secrets](../secrets.md)
