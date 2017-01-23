require 'spec_helper'
require 'centurion/deploy_dsl'
require 'capistrano_dsl'

class DeployDSLTest
  extend Capistrano::DSL
  extend Centurion::DeployDSL
end

describe Centurion::DeployDSL do
  before do
    DeployDSLTest.clear_env
    DeployDSLTest.set_current_environment('test')
  end

  it 'exposes an easy wrapper for handling each Docker host' do
    recipient = double('recipient')
    expect(recipient).to receive(:ping).with('host1')
    expect(recipient).to receive(:ping).with('host2')

    DeployDSLTest.set(:hosts, %w{ host1 host2 })
    DeployDSLTest.on_each_docker_host { |h| recipient.ping(h.hostname) }
  end

  it 'has a DSL method for specifying the start command' do
    command = %w{ /bin/echo hi }
    DeployDSLTest.command command
    expect(DeployDSLTest.defined_service.command).to eq(command)
  end

  it 'adds new env_vars to the existing ones, as strings' do
    DeployDSLTest.env_vars('SHAKESPEARE' => 'Hamlet')
    DeployDSLTest.env_vars('DICKENS' => 'David Copperfield',
                           DICKENS_BIRTH_YEAR: 1812)

    expect(DeployDSLTest.defined_service.env_vars).to eq(
      'SHAKESPEARE'        => 'Hamlet',
      'DICKENS'            => 'David Copperfield',
      'DICKENS_BIRTH_YEAR' => '1812'
    )
  end

  it 'adds new labels to the existing ones, as strings' do
    DeployDSLTest.labels(Shakespeare: 'Hamlet')
    DeployDSLTest.labels(Dickens: 'David Copperfield',
                           Dickens_birth_year: 1812)

    expect(DeployDSLTest.defined_service.labels).to eq(
      'Shakespeare'        => 'Hamlet',
      'Dickens'            => 'David Copperfield',
      'Dickens_birth_year' => '1812'
    )
  end

  describe '#add_capability' do
    it 'adds one capability' do
      DeployDSLTest.add_capability 'IPC_LOCK'
      expect(DeployDSLTest.defined_service.cap_adds).to eq(['IPC_LOCK'])
    end

    it 'adds multiple capabilites' do
      DeployDSLTest.add_capability 'IPC_LOCK'
      DeployDSLTest.add_capability 'SYS_RESOURCE'
      expect(DeployDSLTest.defined_service.cap_adds).to eq(['IPC_LOCK', 'SYS_RESOURCE'])
    end

    it 'fails when an invalid capability is added' do
      lambda{ DeployDSLTest.add_capability 'FOO_BAR' }.should raise_error SystemExit
    end
  end

  describe '#drop_capability' do
    it 'drops one capability' do
      DeployDSLTest.drop_capability 'IPC_LOCK'
      expect(DeployDSLTest.defined_service.cap_drops).to eq(['IPC_LOCK'])
    end

    it 'drops multiple capabilites' do
      DeployDSLTest.drop_capability 'IPC_LOCK'
      DeployDSLTest.drop_capability 'SYS_RESOURCE'
      expect(DeployDSLTest.defined_service.cap_drops).to eq(['IPC_LOCK', 'SYS_RESOURCE'])
    end
  end

  it 'adds hosts to the host list' do
    DeployDSLTest.set(:hosts, [ 'host1' ])
    DeployDSLTest.host('host2')

    expect(DeployDSLTest).to have_key_and_value(:hosts, %w{ host1 host2 })
  end

  describe '#localhost' do
    it 'adds a host by reading DOCKER_HOST if present' do
      expect(ENV).to receive(:[]).with('DOCKER_HOST').and_return('tcp://127.1.1.1:4240')
      DeployDSLTest.localhost
      expect(DeployDSLTest).to have_key_and_value(:hosts, %w[ 127.1.1.1:4240 ])
    end

    it 'adds a host defaulting to loopback if DOCKER_HOST is not present' do
      expect(ENV).to receive(:[]).with('DOCKER_HOST').and_return(nil)
      DeployDSLTest.localhost
      expect(DeployDSLTest).to have_key_and_value(:hosts, %w[ 127.0.0.1 ])
    end
  end

  describe '#host_port' do
    it 'raises unless passed container_port in the options' do
      expect { DeployDSLTest.host_port(666, {}) }.to raise_error(ArgumentError, /:container_port/)
    end

    it 'adds new bind ports to the list' do
      DeployDSLTest.host_port(666, container_port: 666)
      DeployDSLTest.host_port(999, container_port: 80)

      expect(DeployDSLTest.defined_service.port_bindings).to eq([Centurion::Service::PortBinding.new(666, 666, 'tcp'), Centurion::Service::PortBinding.new(999, 80, 'tcp')])
    end

    it 'adds new bind ports to the list with an IP binding when supplied' do
      DeployDSLTest.host_port(999, container_port: 80, host_ip: '0.0.0.0')

      expect(DeployDSLTest.defined_service.port_bindings).to eq([Centurion::Service::PortBinding.new(999, 80, 'tcp', '0.0.0.0')])
    end

    it 'does not explode if port_bindings is empty' do
      expect { DeployDSLTest.host_port(999, container_port: 80) }.not_to raise_error
    end

    it 'raises if invalid options are passed' do
      expect { DeployDSLTest.host_port(80, asdf: 'foo') }.to raise_error(ArgumentError, /invalid key!/)
    end
  end

  describe '#network_mode' do
    it 'accepts host mode' do
      DeployDSLTest.network_mode('host')
      expect(DeployDSLTest.defined_service.network_mode).to eq('host')
    end

    it 'accepts cpu share limit' do
      DeployDSLTest.cpu_shares(12345678)
      expect(DeployDSLTest.defined_service.cpu_shares).to eq(12345678)
    end

    it 'accepts memory limit' do
      DeployDSLTest.memory(12345)
      expect(DeployDSLTest.defined_service.memory).to eq(12345)
    end

    it 'accepts bridge mode' do
      DeployDSLTest.network_mode('bridge')
      expect(DeployDSLTest.defined_service.network_mode).to eq('bridge')
    end

    it 'accepts container link mode' do
      DeployDSLTest.network_mode('container:a2e8937b')
      expect(DeployDSLTest.defined_service.network_mode).to eq('container:a2e8937b')
    end

    it 'fails when invalid mode is passed' do
      expect { DeployDSLTest.network_mode('foo') }.to raise_error(SystemExit)
    end
  end

  describe '#ipc_mode' do
    it 'accepts ipc host mode' do
      DeployDSLTest.ipc_mode('host')
      expect(DeployDSLTest.defined_service.ipc_mode).to eq('host')
    end
  end

  describe '#host_volume' do
    it 'raises unless passed the container_volume option' do
      expect { DeployDSLTest.host_volume('foo', {}) }.to raise_error(ArgumentError, /:container_volume/)
    end

    it 'raises when passed bogus options' do
      expect { DeployDSLTest.host_volume('foo', bogus: 1) }.to raise_error(ArgumentError, /invalid key!/)
    end

    it 'adds new host volumes' do
     expect(DeployDSLTest.fetch(:binds)).to be_nil
     DeployDSLTest.host_volume('volume1', container_volume: '/dev/sdd')
     DeployDSLTest.host_volume('volume2', container_volume: '/dev/sde')
     expect(DeployDSLTest.defined_service.volumes).to eq [Centurion::Service::Volume.new('volume1', '/dev/sdd'), Centurion::Service::Volume.new('volume2', '/dev/sde')]
    end
  end

  describe '#extra_host' do
    it 'adds new hosts to the list' do
      DeployDSLTest.extra_host('192.168.33.10', 'newrelic.dev')
      DeployDSLTest.extra_host('192.168.33.93', 'd.newrelic.dev')

      expect(DeployDSLTest.defined_service.extra_hosts).to eq(['newrelic.dev:192.168.33.10', 'd.newrelic.dev:192.168.33.93'])
    end

    it 'extra_hosts list is nil by default' do
      expect(DeployDSLTest.defined_service.extra_hosts).to eq(nil)
    end
  end

  it 'gets current tags for an image' do
    allow_any_instance_of(Centurion::DockerServer).to receive(:current_tags_for).and_return([ 'foo' ])
    DeployDSLTest.set(:hosts, [ 'host1' ])

    expect(DeployDSLTest.get_current_tags_for('asdf')).to eq [ { server: 'host1', tags: [ 'foo'] } ]
  end

  it 'appends tags to the image name when returning a service' do
    DeployDSLTest.set(:tag, 'roland')
    DeployDSLTest.set(:image, 'charlemagne')
    expect(DeployDSLTest.defined_service.image).to eq('charlemagne:roland')
  end

  describe 'callbacks' do
    shared_examples_for 'a callback for' do |callback_name|
      it 'accepts procs' do
        callback = ->(_) {}
        allow(DeployDSLTest).to receive(:on)
        expect(DeployDSLTest).to receive(:on).with(callback_name, callback)
        DeployDSLTest.send callback_name, callback
      end
    end

    describe '#before_stopping_container' do
      it_behaves_like 'a callback for', :before_stopping_container
    end

    describe '#before_starting_container' do
      it_behaves_like 'a callback for', :before_starting_container
    end

    describe '#after_container_started' do
      it_behaves_like 'a callback for', :after_container_started
    end

    describe '#after_health_check_ok' do
      it_behaves_like 'a callback for', :after_health_check_ok
    end
  end
end
