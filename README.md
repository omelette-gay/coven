# gitops

This repo contains all the infrastructure-as-code stuff for deploying and managing Chris & Meg's server and IoT setup.

# Getting Started

You will need to have [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) to use this repo,
as well as [Helm](https://helm.sh/docs/intro/install/), and Helm Diff (run `helm plugin install https://github.com/databus23/helm-diff` once Helm is installed).

NOTE: If you are running this on Windows, Ansible only runs under WSL, so run everything under WSL (Please see the [How To section](#windows-subsystem-for-linux-install-method) for more information).

In addition, you will also need the following libraries for Python:

- kubernetes: `pip3 install kubernetes`

Our setup uses some external roles for deploying k3s. Run `ansible-galaxy install -r requirements.yml` to bring down
these dependencies.

# Running on real infrastructure

    ansible-playbook -i inventory playbook.yml

In the event you are setting up new things from scratch, then read [the bootstrapping doc](./docs/bootstrapping.md)

# Testlab

To provision a VM which tests out our Ansible scripts and deployments, you will need [Vagrant](https://www.vagrantup.com/)
and Ansible installed. Note that on Windows, this must be installed under WSL. You can then start the testlab by
running `vagrant up`. `vagrant ssh` will then give you a shell on the host machine.

Once the VM is created with `vagrant up` you will need to run: `ansible-playbook -i vagrant-inventory playbook.yml`.
This will run Ansible against the test lab to configure it.

If you want to access Keycloak and Vault locally, then add the following to `/etc/hosts`

```
192.168.57.100 auth.coven.local
192.168.57.100 vault.coven.local
```

# How To

### Configure admin users

There is a group var called `admin_users` which consists of usernames and SSH keys. You can configure this group var
to add a new user and the SSH keys that user can connect from. An existing admin user will first need to run the
Ansible playbook to then add your account to it!

### Windows Subsystem For Linux Install Method

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
