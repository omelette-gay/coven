Vagrant.configure("2") do |config|
  config.vm.box = "bento/fedora-40"

  config.vm.network :private_network, ip: "192.168.57.100"

  config.vm.provision "shell",
                      inline: "nmcli dev mod eth1 ipv4.addresses 192.168.57.100/24; nmcli dev mod eth1 ipv4.method manual"
  
  config.vm.provision :ansible do |ansible|
    ansible.playbook = "plays/vagrant.yml"
    ansible.galaxy_roles_path = "roles/"
    ansible.inventory_path = "vagrant-inventory"
  end
end
