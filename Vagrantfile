Vagrant.configure("2") do |config|
  config.vm.box = "generic/rocky9"

  config.vm.network :private_network, ip: "192.168.57.100"

  config.vm.provision "shell", inline: "systemctl disable firewalld --now"

  # disable the shared folder - we don't need it because we use Ansible to provision things
  # and our Rocky image will break VirtualBox guest additions when it updates which causes
  # `vagrant up` to fail unnecessarily.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |v|
    v.memory = 10240
    v.cpus = 2
  end

  # only configure this on Windows
  if RUBY_PLATFORM =~ /mingw/
    # we are going to have to do some hackery to get the networking on a static IP
    # https://github.com/hashicorp/vagrant/issues/8384

    # on first boot put this on the default switch
    vm_exists = system("powershell.exe", "-Command", "Get-VM -VMNAME coven-testlab -ErrorAction SilentlyContinue | out-null")
    unless vm_exists
      config.vm.network "public_network", bridge: "Default Switch"
    end

    # configure this to go onto a switch in 192.168.57.0/24 we can give a static address to
    config.trigger.before :up do |trigger|
      trigger.info = "Creating 'VagrantSwitch' Hyper-V switch if it does not exist..."
      trigger.run = {privileged: "true", powershell_elevated_interactive: "true", path: "./vagrant-scripts/create-hyperv-switch.ps1"}
    end

    config.trigger.before :reload do |trigger|
      trigger.info = "Setting Hyper-V switch to 'VagrantSwitch' to allow for static IP..."
      trigger.run = {privileged: "true", powershell_elevated_interactive: "true", path: "./vagrant-scripts/set-hyperv-switch.ps1"}
    end

    config.vm.provision "shell", inline: "nmcli con mod eth0 ipv4.method manual ipv4.dns 8.8.8.8 ipv4.address 192.168.57.100/24 ipv4.gateway 192.168.57.1"

    config.vm.provider "hyperv" do |v|
      v.vmname = "coven-testlab"

      v.memory = 10240
      v.maxmemory = 10240
      v.cpus = 2
    end
  end
end
