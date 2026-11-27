# Generated secret

Generates random secret values for something that needs a secret nobody has to know (a password between two of our own
services, a signing key), keeps them in Vault, and syncs them into a Kubernetes Secret.

Terraform writes the values to Vault with a write-only argument, and
[vault-k8s-secret](../vault-k8s-secret/) makes External Secrets Operator create the Secret. Terraform never manages the
Kubernetes Secret, so **the values aren't in Terraform state**: a `kubernetes_secret_v1` would have its contents read back
into state even if it was written with `data_wo`. See [secrets and Terraform state](../../docs/secrets.md#secrets-and-terraform-state).

```hcl
module "rcon" {
  source = "../generated-secret"

  keys                     = { "rcon-password" = 32 }
  vault_secret_name        = "minecraft/girlsclub/rcon"
  k8s_secret_name          = "girlsclub-rcon-password"
  k8s_namespace            = kubernetes_namespace_v1.this.metadata[0].name
  k8s_service_account_name = "minecraft-girlsclub-rcon"
  vault_role_name          = "minecraft-girlsclub-rcon"
}
```

- The Kubernetes Secret is created a moment after Terraform finishes, by ESO. A pod that needs it at once fails to start
  until it exists, then recovers.
- ESO won't take over a Secret that already exists. To move something that already has a Terraform-managed Secret, give
  the new Secret a different name, and delete the old resource.
- Increase `revision` to generate new values. It's written to Vault, and ESO updates the Secret within the refresh
  interval (an hour). Whatever reads the Secret when it starts needs restarting.
- The values in `keys` are random letters and digits only. Use `hex_keys` for a key of an exact number of bytes, such
  as an AES key, which is generated as random bytes and written in lowercase hex.
- Terraform remembers it has written the current `revision` and won't write it again. If a secret is missing from Vault
  when it should exist (Vault was rebuilt without restoring it, or it was deleted), increase `revision` to write new
  values. Restoring Vault from a backup brings the secrets back with it, so that needs nothing.
