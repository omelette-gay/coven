Vagrant.configure("2") do |config|
  config.vm.box = "bento/fedora-40"

  config.vm.provision :ansible do |ansible|
    ansible.playbook = "plays/vagrant.yml"
    ansible.galaxy_roles_path = "roles/"
    ansible.inventory_path = "vagrant-inventory"
  end
end
