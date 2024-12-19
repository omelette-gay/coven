# gitops

This repo contains all the infrastructure-as-code stuff for deploying and managing Chris & Meg's server and IoT setup.

# Getting Started

You will need to have [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) to use this repo,
as well as [Helm](https://helm.sh/docs/intro/install/), Helm Diff (run `helm plugin install https://github.com/databus23/helm-diff` once Helm is installed)
and [Vault](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install).

NOTE: If you are running this on Windows, Ansible only runs under WSL, so run everything under WSL (Please see the [How To section](#windows-subsystem-for-linux-install-method) for more information).

In addition, you will also need the following libraries for Python:

- kubernetes: `pip3 install kubernetes`
- ansible-modules-hashivault: `pip3 install ansible-modules-hashivault`

Our setup uses some external roles for deploying k3s. Run `ansible-galaxy install -r requirements.yml` to bring down
these dependencies.

# Running on real infrastructure

You will first need to log in to Vault to access the secrets needed for deployment (unless you are bootstrapping!)

    export VAULT_ADDR=https://vault.coven.omelette.gay
    vault login -method=oidc -path=keycloak role=admin

Now you can run the playbook:

    ansible-playbook -i inventory playbook.yml

In the event you are setting up new things from scratch, then read [the bootstrapping doc](./docs/bootstrapping.md)

# Testlab

To provision a VM which tests out our Ansible scripts and deployments, you will need [Vagrant](https://www.vagrantup.com/)
and Ansible installed. Note that on Windows, this must be installed under WSL. You can then start the testlab by
running `vagrant up`. `vagrant ssh` will then give you a shell on the host machine.

If you want to access Keycloak and Vault locally, then add the following to `/etc/hosts`

    192.168.57.100 auth.coven.local
    192.168.57.100 vault.coven.local

You can then access both at http://auth.coven.local and http://vault.coven.local once deployed.

On first run, see [the bootstrapping doc](./docs/bootstrapping.md) for information on first deploying this, remembering
to specify the inventory as `vagrant-inventory`. Following this, you can specify the following:

    export VAULT_ADDR=http://vault.coven.local
    vault login -method=oidc -path=keycloak role=admin
    ansible-playbook -i vagrant-inventory playbook.yml

# How To

## Log in to the Vault UI

Go to the [Vault login page](http://vault.coven.omelette.gay) and select method "OIDC", role "admin" and under more options
set mount path to "keycloak".

## Configure users for SSH

There is a group var called `ssh_users` which consists of usernames and SSH keys which can sudo. You can configure this group var
to add a new user and the SSH keys that user can connect from. An existing SSH user will first need to run the
Ansible playbook to then add your account to it!

## Stopping crashes on Mac

When trying to read secrets from Vault, Python will regularly crash. You can avoid this by running `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
before running Ansible.

## Windows Subsystem For Linux Install Method

- Install VirtualBox - Vagrant doesn't support all versions of VirtualBox, as of writing this it only accepts the following:
  4.0, 4.1, 4.2, 4.3, 5.0, 5.1, 5.2, 6.0, 6.1, 7.0
  As such I would recommend installing one of the supported versions from: https://www.virtualbox.org/wiki/Download_Old_Builds_7_0

- Install Vagrant using the Windows MSI and note the version (this is important for later)

- Install WSL, if you are unsure how here is a good guide: https://www.thewindowsclub.com/wsl-is-not-working-or-starting-in-windows-11

- Check that you can open Ubuntu (WSL) in Terminal or VSCode
- In the WSL run:

        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update && sudo apt-get install vagrant

This will add the vagrant repo and install vagrant in WSL, note the version installed, it must match the Windows version you installed earlier

- Allow WSL to use Virtualbox and tell it to store vagrant files in the parent folder
  Edit ~/.bashrc to include the following lines and save:

        export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
        export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/<Repo Parent Folder>/"
        export PATH="$PATH:/mnt/d/Programs/Virtualbox"

- Allow WSL to use file permissions properly
  Edit /etc/wsl.conf and add:

        [automount]
        options = "metadata"

  **VAGRANT_WSL_ENABLE_WINDOWS_ACCESS:** Enables Vagrant to use Features that are installed on your Windows client and not within WSL. So for instance Virtualbox itself will then get used from the Windows Client installation and not presuming it is installed within your WSL.
  **VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH:** Path to your user home directory from within WSL. Adjust the entry to your configuration (so username).
  **PATH:** Add the Virtualbox installation path of Virtualbox to your PATH environment variable.

- **Version Check Vagrant**
  Inside WSL run: `vagrant -v`
  This should return the same version that you installed in Windows using the MSI above

- **Install Vagrant virtualbox_WSL2 plugin**
  Inside WSL run: `vagrant plugin install virtualbox_WSL2`

- **Install Ansible in WSL**
  In WSL type: `sudo apt install ansible`

- **Install ansible-galaxy requirements**
  In WSL run: `ansible-galaxy install -r requirements.yml`

- **Install kubernetes**
  In WSL type: `sudo apt install python3-kubernetes`

Now it should all work! You can now carry on from [here.](#getting-started)
