Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"

  config.vm.network :private_network, ip: "192.168.57.100"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 2
  end

  # ensure our important hosts are discoverable from the node
  config.vm.provision "shell", inline: "grep -q auth.coven.local /etc/hosts || echo '192.168.57.100 auth.coven.local' >>/etc/hosts"
end
