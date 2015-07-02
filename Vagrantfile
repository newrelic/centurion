# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = 'trusty'
  config.vm.box_url = 'https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box'

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  config.vm.define 'docker1' do |web|
    web.vm.network 'private_network', ip: '10.11.11.111'
  end

  config.vm.define 'docker2' do |web|
    web.vm.network 'private_network', ip: '10.11.11.112'
  end

  config.vm.provision 'shell', inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install wget aufs-tools
    wget -qO- https://get.docker.com/ | sh
    echo "export DOCKER_OPTS='-H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock'" >> /etc/default/docker
    usermod -aG docker vagrant
    service docker restart
  SHELL
end
