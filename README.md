# gitops

This repo contains all the infrastructure-as-code stuff for deploying and managing Chris & Meg's server and IoT setup.

# Getting Started

NOTE: If you are running this on Windows, Ansible only runs under WSL, so run everything under WSL.

You will need to have the following installed (in your WSL environment if on Windows):

- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [Helm](https://helm.sh/docs/intro/install/)
- Helm Diff: `helm plugin install https://github.com/databus23/helm-diff`
- [Vault](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management)
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install#deb)

Our setup uses some external roles for deploying k3s. Run `uv run ansible-galaxy install -r requirements.yml` to bring down
these dependencies.

You will need to run `terraform init` in each environment's folder (`coven/` and `testlab/`) to set up your
Terraform sessions. You will need to re-run this if the Terraform lock file changes (you will be warned of
this if you run `terraform` without doing so).

In the event you are setting up new things from scratch, then read [the bootstrapping doc](./docs/bootstrapping.md).

# Running on real infrastructure

You will first need to log in to Vault to access the secrets needed for deployment (unless you are bootstrapping!).
This will also log you in to allow you to use kubectl locally.

    ./login.sh --coven

Now you can run the playbook:

    uv run ansible-playbook -i coven/inventory plays/configure-hosts.yml

If you want to run Terraform locally, you will also need to log in to GCP.

    gcloud auth application-default login

Now you can run `terraform apply` in the `coven/` folder to apply any Terraform changes.

# Testlab

To provision a VM which tests out our Ansible scripts and deployments, you will need [Vagrant](https://www.vagrantup.com/) installed,
as well as the other pre-requisites defined above.

> [!IMPORTANT]
> Although most of the dependencies are one time install per machine and managed using your regular package manager,
> the external Ansible roles we use are not, and you will need to update these periodically for your test lab:
> `uv run ansible-galaxy install -r requirements.yml --force`.

> [!NOTE]
> **Note that on Windows, Vagrant must be installed on the Windows side**, as it runs under Hyper-V. Everything other than
> Vagrant then runs in WSL. VirtualBox and WSL2 do not run side-by-side. On Windows, as Vagrant must run as admin to
> control Hyper-V, there is a helper script in the repo called `./vagrant.ps1` which you can use in WSL to run Vagrant
> as admin in Windows, so below you can run `./vagrant.ps1 up` etc to start the VM, without having to leave WSL yourself.

You can then start the testlab by running `vagrant up` (`./vagrant.ps1 up`). On the first run on Windows you must then `vagrant reload` (`./vagrant.ps1 reload`)
to complete the configuration of the new static IP network.

> [!TIP]
> If you're booting up the testlab for the first time in a while, you will need to [unseal Vault](#restart-and-unseal-vault-after-a-deploy-or-reboot),
> and you might not have a valid token. To get working auth set up, run `./bootstrap-auth.sh --local` to copy over the
> system credentials from your testlab and you can use `kubectl` like usual, then `./login.sh --local` to properly auth
> using Vault and Keycloak.

To SSH in the testlab you can run: `ssh -i .vagrant/machines/default/hyperv/private_key vagrant@192.168.57.100`.
If you are installing (or re-installing) a new testlab, you need to trust the testlab's SSH server key:

    chmod 600 .vagrant/machines/default/hyperv/private_key
    ssh-keygen -R 192.168.57.100
    ssh -i .vagrant/machines/default/hyperv/private_key vagrant@192.168.57.100

To access Keycloak, Vault and Grafana locally, add the following to `/etc/hosts` (or `C:\Windows\system32\drivers\etc\hosts`).

    192.168.57.100 auth.coven.local
    192.168.57.100 vault.coven.local
    192.168.57.100 monitoring.coven.local

On first run, see [the bootstrapping doc](./docs/bootstrapping.md) for information on first deploying this, remembering
to specify the inventory as `testlab/inventory`. Following this, you can specify the following:

    ./login.sh --local
    uv run ansible-playbook -i testlab/inventory plays/configure-hosts.yml

# How To

## Restart and unseal Vault after a deploy or reboot

Our Vault is not configured to "auto-unseal", so on first boot, it requires unseal codes (which are stored offline) to
be entered into it. This means that after running Ansible, if that changes Vault, you will need to manually cause
Vault to restart it (otherwise it'll break itself in the middle of a run). Run `kubectl -n vault delete pod vault-0`.

You will then need to unseal Vault before the UI becomes available. You can do this by running `kubectl -n vault exec -it vault-0 -- vault operator unseal`
(if you are not logged into k8s at the time, you will need to SSH and run it on the host as root).

## Log in to the Vault UI

Go to the [Vault login page](http://vault.coven.omelette.gay) and select method "OIDC", role "admin" and under more options
set mount path to "keycloak".

## Stop crashes on Mac

When trying to read secrets from Vault, Python will regularly crash. You can avoid this by running `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
before running Ansible.

## Debug Traefik

One of the best ways to look at Traefik issues is to interrogate the state via the Traefik dashboard. This is
enabled in "insecure" mode on our cluster, but this is okay as it's not directly exposed anywhere. To see it,
we'll need to be logged into the cluster and then create a port forward to our local machine to look at it.

    kubectl -n kube-system port-forward deployments/traefik 8080:8080

We can now visit http://localhost:8080/dashboard/ to view the dashboard.

## Access the Longhorn console

     kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80

You can now visit http://localhost:8080/ to view the Longhorn dashboard.

## Configure users for SSH

There is a group var called `ssh_users` which consists of usernames and SSH keys which can sudo. You can configure this group var
to add a new user and the SSH keys that user can connect from. An existing SSH user will first need to run the
Ansible playbook to then add your account to it!

## Fix file permissions in WSL

You will need to edit WSL's config to let permissions to be read correctly. Edit /etc/wsl.conf and add:

    [automount]
    options = "metadata,umask=022,fmask=111"

This however will stop us executing some Windows files that we need to run Vagrant, to fix this, in your WSL
environment, create a file `/etc/systemd/system/mnt-c-WINDOWS.mount`:

    [Unit]
    Description=remount Windows allowing exec bits
    After=mnt-c.mount

    [Mount]
    What=C:/WINDOWS
    Where=/mnt/c/WINDOWS
    Type=drvfs
    Options=

    [Install]
    WantedBy=multi-user.target

And also `/etc/systemd/system/mnt-c-Program\x20Files.mount` (be careful of the `\` here, that will need escaping again in the shell).

    [Unit]
    Description=remount Program Files allowing exec bits
    After=mnt-c.mount

    [Mount]
    What=C:/Program Files
    Where=/mnt/c/Program Files
    Type=drvfs
    Options=

    [Install]
    WantedBy=multi-user.target

Now `systemctl daemon-reload` and `systemctl enable mnt-c-WINDOWS.mount`, `sudo systemctl enable 'mnt-c-Program\x20Files.mount'`
and in a Windows terminal, run `wsl --shutdown`. Next time you load your WSL instance it will now have file permissions correctly configured.

## Linux tab completion for kubectl objects

First make sure that Bash-Completion is installed: `sudo apt install bash-completion`

Once Base-Completion is installed you'll need to run the following to enable kubectl autocompletion in bash for the entire system:

    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    sudo chmod a+r /etc/bash_completion.d/kubectl
