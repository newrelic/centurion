# -*- mode: ruby -*-
# vi: set ft=ruby :

#
# Docker-fleet - Spins up a fleet of docker enabled machines on Ubuntu 14.04
#

require 'fileutils'

# Defaults for config options defined in CONFIG
$num_instances = 3

# Vagrantfile API/syntax version.
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  #config.vm.box = "precise64"
  config.vm.box = "ubuntu/trusty64"

  (1..$num_instances).each do |i|
    config.vm.define vm_name = "docker-fleet-%02d" % i do |config|

      config.vm.hostname = vm_name
      config.vm.network "private_network", type: "dhcp"

      # Provider-specific configuration so you can fine-tune various
      # backing providers for Vagrant. These expose provider-specific options.
      # Example for VirtualBox:
      #
      config.vm.provider :virtualbox do |vb|
        #   # Don't boot with headless mode
        #   vb.gui = true
        #
        #   # Use VBoxManage to customize the VM. For example to change memory:
        vb.customize ["modifyvm", :id, "--memory", "1024"]
      end

      if File.exist?("./vagrant/user-data")
        config.vm.provision "shell", path: "./vagrant/user-data"
      end

    end
  end



end
