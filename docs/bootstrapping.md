# Bootstrapping

When we first deploy something, there will often have to be something a bit non-standard done,
e.g., because the automation user accounts aren't set up. This guide documents what those
might be.

## Building the cluster services from scratch

This is how the testlab is built, and how coven would be rebuilt without restoring its datastore (see
[ADR 002](./adr/002-three-stack-terraform-for-cluster-configuration.md#building-a-fresh-cluster)). The examples are for
the testlab; use `--coven` instead of `--local` for coven. If the stacks still have `imports.tf` files from a
migration, delete them locally first, as there's nothing to import on a fresh cluster.

1. Run the host playbook, so k3s is installed:

       uv run ansible-playbook -i testlab/inventory plays/configure-hosts.yml

2. Get cluster-admin credentials from the node, as Vault and Keycloak don't exist yet, and choose a password for
   Keycloak's temporary admin. Keep this shell open: both bootstrap and platform need the password.

       ./bootstrap-auth.sh --local
       export TF_VAR_keycloak_bootstrap_admin_password=$(openssl rand -hex 24)
       ./terraform.sh --local apply bootstrap

   Keycloak creates a temporary admin, `temp-admin`, in the master realm with that password when it first starts.

3. Initialise and unseal Vault, and log in with the root token. On the testlab you may prefer a single unseal key for
   speed (`-key-shares=1 -key-threshold=1`):

       kubectl -n vault exec -it vault-0 -- vault operator init
       kubectl -n vault exec -it vault-0 -- vault operator unseal
       vault login -address https://vault.coven.local -tls-skip-verify

   On coven, also write the Hetzner API token to Vault now (see [external API keys](#external-api-keys)).

4. Apply platform. With the temporary admin's password still set, it logs in to Keycloak as `temp-admin`, and creates
   the realm, Vault's configuration (including GitHub Actions' access) and Terraform's own Keycloak user,
   `ansible-automation`, whose password it writes to Vault. Terraform logs in as that user from now on:

       ./terraform.sh --local apply platform

5. Log in to Keycloak as `temp-admin` and create yourself two users:

   - In the `omelette.gay` realm (the one used to log in to everything other than Keycloak's own admin console), and
     add it to the `admins` group. Check you can log in with `./login.sh --local`.
   - In the master realm, for administering Keycloak itself: set a password that isn't temporary, and assign it the
     `admin` realm role. Check you can log in to the admin console with it, as `temp-admin` is about to go.

   `ansible-automation` is also a master-realm admin, but it's Terraform's. Only use its credentials (in Vault at
   `gitops/keycloak-master-credentials`) as break-glass.

6. Delete `temp-admin` in the master realm, unset the password, and apply bootstrap again, which deletes the Secret
   that held it. Then revoke the root token, and apply apps:

       unset TF_VAR_keycloak_bootstrap_admin_password
       ./terraform.sh --local apply bootstrap
       vault token revoke -address https://vault.coven.local -tls-skip-verify <the root token from step 3>
       ./terraform.sh --local apply apps

   Pass the root token itself rather than using `-self`: `./login.sh` replaced the token the Vault CLI uses with your
   own, which is what you use from now on. On coven, CI takes over from here.

## Deploying to physical hardware on Hetzner

Once a Hetzner server is configured, you are launched into [Hetzner's rescue system](https://docs.hetzner.com/robot/dedicated-server/troubleshooting/hetzner-rescue-system/).
If we ever want to rebuild a server, we can use Hetzner's Robot to reboot a system into the rescue system. You can
then SSH into the box as `root` using the public key selected when rebooting into the rescue system.

Running `installimage` on the system, and then selecting Rocky Linux 9 will give us a config file where we can
configure our OS and disk partitioning (we are currently using RAID-1). Importantly on k3s nodes we also want to
disable swap so can remove the swap partition.

Once the OS has been installed, we have a blank system where we can then SSH in as root using the same SSH key.
On first install, we need to tell Ansible to SSH in using `root` so run that first Ansible command as:

    ANSIBLE_REMOTE_USER=root uv run ansible-playbook plays/configure-hosts.yml -i coven/inventory -l my-new-server

## Other fresh installs

For other machines, we install a fresh install of Rocky from the minimal installer, with a single large `/`
partition (other than the bootloader). You will want to create your user during the initial setup, and once
installed, SSH into it and copy your SSH key so you can run an initial provision using Ansible.

We also want to enable passwordless sudo, which you can do by running `visudo` to edit `/etc/sudoers`
and uncommenting the relevant line (and commenting out the other one), such as the section that mentions `wheel`
looks like so:

    ## Allows people in group wheel to run all commands
    # %wheel        ALL=(ALL)       ALL

    ## Same thing without a password
    %wheel  ALL=(ALL)       NOPASSWD: ALL

This will allow Ansible to then run (this may be automated in future).

## External API keys

You will need to [create an API token](https://docs.hetzner.com/dns-console/dns/general/api-access-token/) for DNS in Hetzner
and store this in Vault under the `gitops/hetzner` secret in the key `api_token`.

## Initialising new GCP account / project with Terraform

As default Terraform is configured to store state in a GCP bucket, when initially setting up the project you will have to
disable the `backend "gcs"` block in `coven/bootstrap/`, then run Terraform locally, reenable the `backend "gcs"` block and migrate state with
`terraform init -migrate-state`.

Once the initial project is created, you will also need to populate the secret `k3s-cluster-token` in GCP with the
token for the cluster (in `/var/lib/rancher/k3s/server/token` on a controller).

If the `omelette.gay` zone is new too, it has no records for the cluster yet, but Vault and Keycloak need theirs to get
certificates before platform (which installs external-dns) can be applied. Add A and AAAA records by hand in Hetzner's
DNS console for `vault.coven`, `auth.coven` and `monitoring.coven`, pointing at strix's public addresses. Once platform
is applied and external-dns is running, delete them: external-dns won't change records it didn't make, and recreates
them as its own. (Rebuilding the cluster on its own doesn't need this, as the records are kept in Hetzner.)

# GitHub actions

GitHub's SSH keys are deployed onto the servers via Ansible, however GitHub needs also to be configured to trust
the SSH keys of the hosts. This is done by configuring the SSH_KNOWN_HOSTS secret in the GitHub environment. You can
make this file by running `ssh-keyscan <host>` for each host in the inventory and combining it together into that secret.
