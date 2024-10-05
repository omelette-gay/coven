gitops
======

This repo contains all the infrastructure-as-code stuff for deploying and managing Chris & Meg's server and IoT setup.

Getting Started
---------------

NOTE: If you are running this on Windows, Ansible only runs under WSL, so run everything under WSL.

You will need to have [Ansible installed](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) to use this repo.

In addition, you will also need the following libraries for Python:
* kubernetes: `pip3 install kubernetes`

Our setup uses some external roles for deploying k3s. Run `ansible-galaxy install -r requirements.yml` to bring down
these dependencies.

Testlab
-------

To provision a VM which tests out our Ansible scripts and deployments, you will need [Vagrant](https://www.vagrantup.com/)
and Ansible installed. Note that on Windows, this must be installed under WSL. You can then start the testlab by
running `vagrant up`. `vagrant ssh` will then give you a shell on the host machine.

How To
------

### Configure admin users

There is a group var called `admin_users` which consists of usernames and SSH keys. You can configure this group var
to add a new user and the SSH keys that user can connect from. An existing admin user will first need to run the
Ansible playbook to then add your account to it!
