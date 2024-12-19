# Bootstrapping

When we first deploy something, there will often have to be something a bit non-standard done,
e.g., because the automation user accounts aren't set up. This guide documents what those
might be.

## First deploy of SSO

When first deploying the SSO configuration, you will need to specify the initial user for Keycloak
on the command line and enable the bootstrapping flag:

    ansible-playbook -i INSERT-INVENTORY -e 'bootstrap_keycloak=true keycloak_username=USERNAME keycloak_password=PASSWORD' playbook.yml

You will now be able to go to Keycloak and log in using that username and password. You should change
this password after bootstrapping as it is stored in plaintext in the config for Keycloak.

Your initial login will be created in the master realm, which is the realm used for managing the domain. You
should log in and create yourself a user in the "omelette.gay" realm which is the one that's actually used for
logging in to things that are not admining Keycloak. This user should also be put in the "admins" group
so you can log in to Vault using this login.

On first run, you will error the first time you need to interact with Vault. You will need to go to the Vault
UI and run through the init sequence, storing the initial secrets and make a copy of your root token, then
unsealing Vault.

You can now log in using your root token, e.g., if in Vagrant: `vault login -address http://vault.coven.local` and continue the deploy by re-running Ansible.

Once you are in and can confirm you can sign in to Vault using Keycloak, now revoke the root token: `vault token revoke -address https://vault.coven.local -self`.

The final step is to create a user in Keycloak's master realm to enable automation. Make sure you are in the master realm
and add a user in Keycloak. Once created, under role mappings, ensure this new user is assigned the "admin" role.
Finally, generate a secure password and do not set it as "temporary" and then set this password in the Credentials tab.

In Vault, now create a secret called "gitops/keycloak-master-credentials" with two pieces of data in it, one called
"username" which has the name of the user you just created, and the other called "password" which contains the password.

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

    ANSIBLE_REMOTE_USER=root ansible-playbook playbook.yml -i inventory -l my-new-server 
