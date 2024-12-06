# Bootstrapping

When we first deploy something, there will often have to be something a bit non-standard done,
e.g., because the automation user accounts aren't set up. This guide documents what those
might be.

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
