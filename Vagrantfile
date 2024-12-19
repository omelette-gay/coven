Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"

  config.vm.network :private_network, ip: "192.168.57.100"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 2
  end
end
