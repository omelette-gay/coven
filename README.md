# gitops

This repo contains all the infrastructure-as-code stuff for deploying and managing Chris & Meg's server and IoT setup.

# Getting Started

NOTE: If you are running this on Windows, Ansible only runs under WSL, so run everything under WSL (Please see the [How To section](#windows-subsystem-for-linux-install-method) for more information).

You will need to have the following installed:
 
- Ansible: `sudo pip3 install ansible --break-system-packages`
- [Helm](https://helm.sh/docs/intro/install/)
- Helm Diff: `helm plugin install https://github.com/databus23/helm-diff`
- [Vault](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install)
- kubernetes for Python: `sudo pip3 install kubernetes --break-system-packages`
- ansible-modules-hashivault: `sudo pip3 install ansible-modules-hashivault --break-system-packages`

Our setup uses some external roles for deploying k3s. Run `ansible-galaxy install -r requirements.yml` to bring down
these dependencies.

# Running on real infrastructure

You will first need to log in to Vault to access the secrets needed for deployment (unless you are bootstrapping!).
This will also log you in to allow you to use kubectl locally.

    ./login.sh --coven

Now you can run the playbook:

    ansible-playbook -i inventory playbook.yml

In the event you are setting up new things from scratch, then read [the bootstrapping doc](./docs/bootstrapping.md)

# Testlab

To provision a VM which tests out our Ansible scripts and deployments, you will need [Vagrant](https://www.vagrantup.com/) installed,
as well as the other pre-requisites defined above.

Note that on Windows, this must be installed under WSL. You can then start the testlab by running `vagrant up`.
`vagrant ssh` will then give you a shell on the host machine.

If you want to access Keycloak and Vault locally, then add the following to `/etc/hosts`

    192.168.57.100 auth.coven.local
    192.168.57.100 vault.coven.local

You can then access both at http://auth.coven.local and http://vault.coven.local once deployed.

On first run, see [the bootstrapping doc](./docs/bootstrapping.md) for information on first deploying this, remembering
to specify the inventory as `vagrant-inventory`. Following this, you can specify the following:

    ./login.sh --local
    ansible-playbook -i vagrant-inventory playbook.yml

# How To

## Restarting Vault after a deploy

Our Vault is not configured to "auto-unseal", so on first boot, it requires unseal codes (which are stored offline) to
be entered into it. This means that after running Ansible, if that changes Vault, you will need to manually cause
Vault to restart it (otherwise it'll break itself in the middle of a run). Run `kubectl -n vault delete pod vault-0`.

You will then need to unseal Vault before the UI becomes available. You can do this by running `kubectl -n vault exec -it vault-0 -- vault operator unseal`
(if you are not logged into k8s at the time, you will need to SSH and run it on the host as root).

## Log in to the Vault UI

Go to the [Vault login page](http://vault.coven.omelette.gay) and select method "OIDC", role "admin" and under more options
set mount path to "keycloak".

## Stopping crashes on Mac

When trying to read secrets from Vault, Python will regularly crash. You can avoid this by running `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
before running Ansible.

## Configure users for SSH

There is a group var called `ssh_users` which consists of usernames and SSH keys which can sudo. You can configure this group var
to add a new user and the SSH keys that user can connect from. An existing SSH user will first need to run the
Ansible playbook to then add your account to it!

## Windows Subsystem For Linux Install Method

1. Install VirtualBox
2. Install WSL, if you are unsure how here is a good guide: https://www.thewindowsclub.com/wsl-is-not-working-or-starting-in-windows-11
3. Check that you can open Ubuntu (WSL) in Terminal or VSCode
4. In the WSL run:

        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install vagrant

    This will add the vagrant repo and install vagrant in WSL, note the version installed, it must match the Windows version you installed earlier

5. Allow WSL to use Virtualbox and tell it to store vagrant files in the parent folder
   Edit ~/.bashrc to include the following lines and save:

        export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
        export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/<Repo Parent Folder>/"
        export PATH="$PATH:/mnt/<Path to VirtualBox install>"

   You will then need to reload your terminal

6. Allow WSL to use file permissions properly
    Edit /etc/wsl.conf and add:

        [automount]
        options = "metadata"

    **VAGRANT_WSL_ENABLE_WINDOWS_ACCESS:** Enables Vagrant to use Features that are installed on your Windows client and not within WSL. So for instance Virtualbox itself will then get used from the Windows Client installation and not presuming it is installed within your WSL.
    **VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH:** Path to your user home directory from within WSL. Adjust the entry to your configuration (so username).
    **PATH:** Add the Virtualbox installation path of Virtualbox to your PATH environment variable.

7. **Install Vagrant virtualbox_WSL2 plugin**
   Inside WSL run: `vagrant plugin install virtualbox_WSL2`

Now it should all work! You can now carry on from [here.](#getting-started)
