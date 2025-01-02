Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"

  config.vm.network :private_network, ip: "192.168.57.100"

  # disable the shared folder - we don't need it because we use Ansible to provision things
  # and our Rocky image will break VirtualBox guest additions when it updates which causes
  # `vagrant up` to fail unnecessarily.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |v|
    v.memory = 8192
    v.cpus = 2
  end
end
