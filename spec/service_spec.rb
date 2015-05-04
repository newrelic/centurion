require 'spec_helper'
require 'centurion/service'

describe Centurion::Service do
  let(:service)  { Centurion::Service.new(:redis) }
  let(:hostname) { 'shakespeare' }
  let(:image)    { 'redis' }

  it 'creates a service from a hash' do
    svc = Centurion::Service.from_hash(
      'mycontainer',
      image: image,
      hostname: hostname,
      dns: nil,
      volumes: [ { host_volume: '/foo', container_volume: '/foo/bar' } ],
      port_bindings: [ { host_port: 12340, container_port: 80, type: 'tcp' } ]
    )

    expect(svc.name). to eq('mycontainer')
    expect(svc.hostname).to eq(hostname)
    expect(svc.dns).to be_nil
    expect(svc.volumes.size).to eq(1)
    expect(svc.volumes.first.host_volume).to eq('/foo')
    expect(svc.port_bindings.size).to eq(1)
    expect(svc.port_bindings.first.container_port).to eq(80)
  end

  it 'has an associated hostname' do
    service.hostname = 'example.com'
    expect(service.hostname).to eq('example.com')
  end

  it 'starts with a command' do
    service.command = ['redis-server']
    expect(service.command).to eq(['redis-server'])
  end

  it 'has memory bounds' do
    service.memory = 1024
    expect(service.memory).to eq(1024)
  end

  it 'rejects non-numeric memory bounds' do
    expect(-> { service.memory = 'all' }).to raise_error
  end

  it 'has cpu shares bounds' do
    service.cpu_shares = 512
    expect(service.cpu_shares).to eq(512)
  end

  it 'rejects non-numeric cpu shares' do
    expect(-> { service.cpu_shares = 'all' }).to raise_error
  end

  it 'has a custom dns association' do
    service.dns = 'redis.example.com'
    expect(service.dns).to eq('redis.example.com')
  end

  it 'boots from a docker image' do
    service.image = 'registry.hub.docker.com/library/redis'
    expect(service.image).to eq('registry.hub.docker.com/library/redis')
  end

  it 'has env vars' do
    service.add_env_vars(SLAVE_OF: '127.0.0.1')
    service.add_env_vars(USE_AOF: '1')
    expect(service.env_vars).to eq(SLAVE_OF: '127.0.0.1', USE_AOF: '1')
  end

  it 'has volume bindings' do
    service.add_volume('/volumes/redis/data', '/data')
    service.add_volume('/volumes/redis/config', '/config')
    expect(service.volumes).to eq([Centurion::Service::Volume.new('/volumes/redis/data', '/data'),
                                   Centurion::Service::Volume.new('/volumes/redis/config', '/config')])
  end

  it 'has port mappings' do
    service.add_port_bindings(8000, 6379, 'tcp', '127.0.0.1')
    service.add_port_bindings(18000, 16379, 'tcp', '127.0.0.1')
    expect(service.port_bindings).to eq([Centurion::Service::PortBinding.new(8000, 6379, 'tcp', '127.0.0.1'),
                                         Centurion::Service::PortBinding.new(18000, 16379, 'tcp', '127.0.0.1')])
  end

  it 'builds a list of public ports for the service' do
    service.add_port_bindings(8000, 6379, 'tcp', '127.0.0.1')
    service.add_port_bindings(18000, 16379, 'tcp', '127.0.0.1')
    expect(service.public_ports).to eq([8000, 18000])
  end

  it 'builds a valid docker container configuration' do
    service = Centurion::Service.new(:redis)
    service.image = 'http://registry.hub.docker.com/library/redis'
    service.command = ['redis-server', '--appendonly', 'yes']
    service.memory = 1024
    service.cpu_shares = 512
    service.add_env_vars(SLAVE_OF: '127.0.0.2')
    service.add_port_bindings(8000, 6379, 'tcp', '10.0.0.1')
    service.add_volume('/volumes/redis.8000', '/data')

    expect(service.build_config('example.com')).to eq({
      'Image' => 'http://registry.hub.docker.com/library/redis',
      'Hostname' => 'example.com',
      'Cmd' => ['redis-server', '--appendonly', 'yes'],
      'Memory' => 1024,
      'CpuShares' => 512,
      'ExposedPorts' => {'6379/tcp' => {}},
      'Env' => ['SLAVE_OF=127.0.0.2'],
      'Volumes' => {'/data' => {}},
      'VolumesFrom' => 'parent'
    })
  end

  it 'interpolates hostname into env variables' do
    allow(Socket).to receive(:getaddrinfo).and_return([["AF_INET", 0, "93.184.216.34", "93.184.216.34", 2, 1, 6]])
    service = Centurion::Service.new(:redis)
    service.add_env_vars(HOST: '%DOCKER_HOSTNAME%')

    expect(service.build_config('example.com')['Env']).to eq(['HOST=example.com'])
  end

  it 'interpolates host ip into env variables' do
    allow(Socket).to receive(:getaddrinfo).and_return([["AF_INET", 0, "93.184.216.34", "93.184.216.34", 2, 1, 6]])
    service = Centurion::Service.new(:redis)
    service.add_env_vars(HOST: '%DOCKER_HOST_IP%')

    expect(service.build_config('example.com')['Env']).to eq(['HOST=93.184.216.34'])
  end

  it 'builds a valid docker host configuration' do
    service = Centurion::Service.new(:redis)
    service.dns = 'example.com'
    service.add_port_bindings(8000, 6379)
    service.add_volume('/volumes/redis.8000', '/data')

    expect(service.build_host_config(Centurion::Service::RestartPolicy.new('on-failure', 10))).to eq({
      'Binds' => ['/volumes/redis.8000:/data'],
      'PortBindings' => {
        '6379/tcp' => [{'HostPort' => '8000'}]
      },
      'Dns' => 'example.com',
      'RestartPolicy' => {
        'Name' => 'on-failure',
        'MaximumRetryCount' => 10
      }
    })
  end

  it 'ignores garbage restart policy' do
    service = Centurion::Service.new(:redis)

    expect(service.build_host_config(Centurion::Service::RestartPolicy.new('garbage'))).to eq({
       'Binds' => [],
       'PortBindings' => {},
       'RestartPolicy' => {
         'Name' => 'on-failure',
         'MaximumRetryCount' => 10
       }
     })
  end

  it 'accepts "no" restart policy' do
    service = Centurion::Service.new(:redis)

    expect(service.build_host_config(Centurion::Service::RestartPolicy.new('no'))).to eq({
      'Binds' => [],
      'PortBindings' => {},
       'RestartPolicy' => {
         'Name' => 'no',
       }
     })
  end

  it 'accepts "always" restart policy' do
    service = Centurion::Service.new(:redis)

    expect(service.build_host_config(Centurion::Service::RestartPolicy.new('always'))).to eq({
      'Binds' => [],
      'PortBindings' => {},
       'RestartPolicy' => {
         'Name' => 'always',
       }
     })
  end

  it 'accepts "on-failure" restart policy with retry count' do
    service = Centurion::Service.new(:redis)

    expect(service.build_host_config(Centurion::Service::RestartPolicy.new('on-failure', 50))).to eq({
      'Binds' => [],
      'PortBindings' => {},
       'RestartPolicy' => {
         'Name' => 'on-failure',
         'MaximumRetryCount' => 50
       }
     })
  end

  it 'builds docker configuration for volume binds' do
    service.add_volume('/volumes/redis/data', '/data')
    expect(service.volume_binds_config).to eq(['/volumes/redis/data:/data'])
  end

  it 'builds docker configuration for port bindings' do
    service.add_port_bindings(8000, 6379, 'tcp', '127.0.0.1')
    expect(service.port_bindings_config).to eq({
      '6379/tcp' => [{'HostPort' => '8000', 'HostIp' => '127.0.0.1'}]
    })
  end

  it 'builds docker configuration for port bindings without host ip' do
    service.add_port_bindings(8000, 6379, 'tcp')
    expect(service.port_bindings_config).to eq({
      '6379/tcp' => [{'HostPort' => '8000'}]
    })
  end
end

