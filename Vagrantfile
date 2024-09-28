Vagrant.configure("2") do |config|
  config.vm.box = "bento/fedora-40"

  # Because we use a static inventory rather than use the fake/auto-generated one Vagrant generates we have to
  # specify the IP address to connect to in the inventory ourselves.
  # The default 127.0.0.1 port forwarding works on Mac and Linux, but not when run inside WSL, so we create a
  # private network with a known static IP and connect to that so it's consistent along all of our local
  # environments. We have to configured this a bit manually rather than relying on Vagrant to do it for us, as
  # Vagrant does not support configuring the version of Fedora we're using
  # https://github.com/hashicorp/vagrant/issues/12762
  config.vm.network :private_network, ip: "192.168.57.100", libvirt__dhcp_enabled: false

  config.vm.provision "shell",
                      inline: "nmcli dev mod eth1 ipv4.addresses 192.168.57.100/24; nmcli dev mod eth1 ipv4.method manual"
  
  config.vm.provision :ansible do |ansible|
    ansible.playbook = "playbook.yml"
    ansible.inventory_path = "vagrant-inventory"
  end
end
