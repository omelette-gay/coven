# The `minio/mc` image became unpullable, which failed the platform apply and left GlitchTip half-migrated

| | |
|---|---|
| **Status** | Ongoing |
| **Detected** | 2026-11-14, by the failed `tfapply.yml` run. The time the stuck-job alert first fired isn't known (see follow-up actions) |
| **Impact started** | 2026-11-14 14:13 UTC (the apply deleted GlitchTip's old Secrets) |
| **Resolved** | Not yet |
| **Severity** | Minor (GlitchTip is an internal error tracker, though its impact on stored data is unconfirmed) |
| **Alerts** | A stuck-job alert for `glitchtip/create-glitchtip-bucket-glitchtip` (exact name to be confirmed) |

## Summary

Merging [PR #911](https://github.com/omelette-gay/gitops/pull/911) ("Keep generated secrets out of Terraform state")
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
| 2026-11-14 14:12 | PR #911 merged to `main` |
| 2026-11-14 14:13 | `tfapply.yml` plans 14 to add, 2 to change, 4 to destroy. The old Secrets and the `configure_oidc` and bucket Jobs are destroyed. New Vault secrets, ExternalSecrets and the new bucket Job are created |
| 2026-11-14 14:14 | New bucket Job created. Its pod goes into `ImagePullBackOff` |
| 2026-11-14 14:24 | Terraform gives up waiting: `job: glitchtip/create-glitchtip-bucket-glitchtip is not in complete state`. Apply fails |
| 2026-11-16 | Stuck-job alert investigated. Docker Hub found to be refusing `minio/mc` (see below) |

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

Once merged, the stuck Job needs to be deleted manually (`kubectl delete job create-glitchtip-bucket-glitchtip -n
glitchtip`) so the CI re-run can recreate it with the new image and finish the GlitchTip migration from PR #911.

## Lessons

- **Went well:** the Secrets migration itself worked. The Vault secrets, ExternalSecrets and SecretStores were created
  and synced, and the RustFS data was never at risk.
- **Didn't go well:** the plan showed the Job being replaced, but nothing flagged that this needed a fresh image pull.
  A `:latest` tag meant we couldn't tell the image had changed or vanished until something pulled it. A failed apply
  also left the old Secrets deleted but the Helm release still pointing at them.
- **Lucky:** the bucket Job was a no-op, and RustFS keeps its data on a PVC separate from the credentials.

## Follow-up actions

- [x] Decide on and pin a replacement for `minio/mc:latest` (Terraform module and Ansible role) — `rustfs/rc:v0.1.37`
- [ ] Unblock the apply, and confirm GlitchTip's web pods and object storage recover
- [ ] Confirm what GlitchTip stores in RustFS and whether anything was lost while the credentials mismatched
- [ ] Confirm which alert fired, and when, and fill in the detection time above
- [ ] Consider whether the bucket Job should be able to fail an apply, or should be ordered so the Helm release is
      updated first when Secrets are renamed
- [ ] Check the other users of `tfmodules/object-store` and `tfmodules/generated-secret` for the same rename (PR #911
      also changed `tfmodules/minecraft`)

## References

- [PR #911: Keep generated secrets out of Terraform state](https://github.com/omelette-gay/gitops/pull/911)
- [Failed `tfapply.yml` run](https://github.com/omelette-gay/gitops/actions/runs/43603668234)
- PR: Replace `minio/mc` with `rustfs/rc` (this PR)
- [Secrets](../secrets.md)
