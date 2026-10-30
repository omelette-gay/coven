# Bootstrapping

When we first deploy something, there will often have to be something a bit non-standard done,
e.g., because the automation user accounts aren't set up. This guide documents what those
might be.

## First deploy of SSO

When first deploying the SSO configuration, you will need to specify the initial user for Keycloak
on the command line and enable the bootstrapping flag:

    uv run ansible-playbook -i INSERT-INVENTORY -e 'bootstrap=true keycloak_username=USERNAME keycloak_password=PASSWORD' plays/configure-cluster.yml

You will now be able to go to Keycloak and log in using that username and password. You should change
this password after bootstrapping as it is stored in plaintext in the config for Keycloak.

Your initial login will be created in the master realm, which is the realm used for managing the domain. You
should log in and create yourself a user in the "omelette.gay" realm which is the one that's actually used for
logging in to things that are not admining Keycloak. This user should also be put in the "admins" group
so you can log in to Vault using this login.

Once k3s is installed on the server, you will need to authenticate to the cluster with the system user until SSO
and Vault are fully installed and configured. There is a `bootstrap-auth.sh` script which will set up your local
k8s credentials to the system user on the box.

On first run, you will error the first time you need to interact with Vault. You will need to go to init Vault with
`kubectl -n vault exec -it vault-0 -- vault operator init`. On the testlab you may prefer to only have a single unlock
key for speed: `kubectl -n vault exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1`.

You can now log in using your root token, e.g., if in Vagrant: `vault login -address https://vault.coven.local -tls-skip-verify`
and continue the deploy by re-running Ansible.

Once you are in and can confirm you can sign in to Vault using Keycloak, now revoke the root token:
`vault token revoke -address https://vault.coven.local -self -tls-skip-verify`.

In future runs, you will not need to specify the extra vars when running ansible.

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
and store this in Vault under the `gitops/hetzner` secret in the key `api_key`.

## Initialising new GCP account / project with Terraform

As default Terraform is configured to store state in a GCP bucket, when initially setting up the project you will have to
disable the `backend "gcs"` block in `coven/bootstrap/`, then run Terraform locally, reenable the `backend "gcs"` block and migrate state with
`terraform init -migrate-state`.

Once the initial project is created, you will also need to populate the secret `k3s-cluster-token` in GCP with the
token for the cluster (in `/var/lib/rancher/k3s/server/token` on a controller).

# GitHub actions

GitHub's SSH keys are deployed onto the servers via Ansible, however GitHub needs also to be configured to trust
the SSH keys of the hosts. This is done by configuring the SSH_KNOWN_HOSTS secret in the GitHub environment. You can
make this file by running `ssh-keyscan <host>` for each host in the inventory and combining it together into that secret.
