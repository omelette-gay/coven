# external-dns

Installs [external-dns](https://kubernetes-sigs.github.io/external-dns/) with Hetzner's webhook, which keeps public DNS
in Hetzner in step with the cluster's ingresses. Called by the platform stack, on coven only.

external-dns only changes records whose ownership TXT records carry `txt_owner_id`, so it leaves records made in
Terraform alone. Its Hetzner API token is synced from Vault.
