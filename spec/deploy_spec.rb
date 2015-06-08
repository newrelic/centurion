require 'spec_helper'
require 'centurion'

describe Centurion::Deploy do
  let(:mock_ok_status)  { double('http_status_ok', status: 200) }
  let(:mock_bad_status) { double('http_status_ok', status: 500) }
  let(:server)          { double('docker_server', attach: true, hostname: hostname) }
  let(:port)            { 8484 }
  let(:container_id)    { '21adfd2ef2ef2349494a' }
  let(:container)       { { 'Ports' => [{ 'PublicPort' => port }, 'Created' => Time.now.to_i ], 'Id' => container_id, 'Names' => [ 'name1' ] } }
  let(:endpoint)        { '/status/check' }
  let(:container_id)    { '21adfd2ef2ef2349494a' }
  let(:test_deploy) do
    Object.new.tap do |o|
      o.send(:extend, Centurion::Deploy)
      o.send(:extend, Centurion::DeployDSL)
      o.send(:extend, Centurion::Logging)
    end
  end
  let(:hostname) { 'host1' }

  before do
    allow(test_deploy).to receive(:fetch).and_return nil
    allow(test_deploy).to receive(:host_ip).and_return('172.16.0.1')
  end

  describe '#http_status_ok?' do
    it 'validates HTTP status checks when the response is good' do
      expect(Excon).to receive(:get).and_return(mock_ok_status)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_truthy
    end

    it 'identifies bad HTTP responses' do
      expect(Excon).to receive(:get).and_return(mock_bad_status)
      allow(test_deploy).to receive(:warn)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_falsey
    end

    it 'outputs the HTTP status when it is not OK' do
      expect(Excon).to receive(:get).and_return(mock_bad_status)
      expect(test_deploy).to receive(:warn).with(/Got HTTP status: 500/)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_falsey
    end

    it 'handles SocketErrors and outputs a message' do
      expect(Excon).to receive(:get).and_raise(Excon::Errors::SocketError.new(RuntimeError.new()))
      expect(test_deploy).to receive(:warn).with(/Failed to connect/)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_falsey
    end
  end

  describe '#container_up?' do
    it 'recognizes when no containers are running' do
      expect(server).to receive(:find_container_by_id).and_return(nil)

      expect(test_deploy.container_up?(server, container_id)).to be_falsey
    end

    it 'recognizes when the container is actually running' do
      expect(server).to receive(:find_container_by_id).and_return(container)
      expect(test_deploy).to receive(:info).with /Found container/

      expect(test_deploy.container_up?(server, container_id)).to be_truthy
    end
  end

  describe '#wait_for_http_status_ok?' do
    before do
      allow(test_deploy).to receive(:info)
    end

    it 'identifies that a container is up' do
      allow(test_deploy).to receive(:container_up?).and_return(true)
      allow(test_deploy).to receive(:http_status_ok?).and_return(true)

      test_deploy.wait_for_health_check_ok(test_deploy.method(:http_status_ok?), server, container_id, port, '/foo', 'image_id', 'chaucer')
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
      expect(test_deploy).to have_received(:info).with('Container is up!')
    end

    it 'waits when the container is not yet up' do
      allow(test_deploy).to receive(:container_up?).and_return(false)
      allow(test_deploy).to receive(:error)
      allow(test_deploy).to receive(:warn)
      expect(test_deploy).to receive(:exit)
      expect(test_deploy).to receive(:sleep).with(0)

      test_deploy.wait_for_health_check_ok(test_deploy.method(:http_status_ok?), server, container_id, port, '/foo', 'image_id', 'chaucer', 0, 1)
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
    end

    it 'waits when the HTTP status is not OK' do
      allow(test_deploy).to receive(:container_up?).and_return(true)
      allow(test_deploy).to receive(:http_status_ok?).and_return(false)
      allow(test_deploy).to receive(:error)
      allow(test_deploy).to receive(:warn)
      expect(test_deploy).to receive(:exit)

      test_deploy.wait_for_health_check_ok(test_deploy.method(:http_status_ok?), server, container_id, port, '/foo', 'image_id', 'chaucer', 1, 0)
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
    end
  end

  describe '#cleanup_containers' do
    it 'deletes all but two containers' do
      service = Centurion::Service.new('walrus')
      expect(server).to receive(:old_containers_for_name).with('walrus').and_return([
        {'Id' => '123', 'Names' => ['walrus-3bab311b460bdf']},
        {'Id' => '456', 'Names' => ['walrus-4bab311b460bdf']},
        {'Id' => '789', 'Names' => ['walrus-5bab311b460bdf']},
        {'Id' => '0ab', 'Names' => ['walrus-6bab311b460bdf']},
        {'Id' => 'cde', 'Names' => ['walrus-7bab311b460bdf']},
      ])
      expect(server).to receive(:remove_container).with('789')
      expect(server).to receive(:remove_container).with('0ab')
      expect(server).to receive(:remove_container).with('cde')

      test_deploy.cleanup_containers(server, service)
    end
  end

  describe '#stop_containers' do
    it 'calls stop_container on the right containers' do
      service = Centurion::Service.new(:centurion)
      service.add_port_bindings(80, 80)

      second_container = container.dup
      containers = [ container, second_container ]

      expect(server).to receive(:find_containers_by_public_port).with(80).and_return(containers)
      expect(server).to receive(:stop_container).with(container['Id'], 30).once
      expect(server).to receive(:stop_container).with(second_container['Id'], 30).once

      test_deploy.stop_containers(server, service)
    end
  end

  describe '#wait_for_load_balancer_check_interval' do
    it 'knows how long to sleep' do
      timing = double(timing)
      expect(test_deploy).to receive(:fetch).with(:rolling_deploy_check_interval, 5).and_return(timing)
      expect(test_deploy).to receive(:sleep).with(timing)

      test_deploy.wait_for_load_balancer_check_interval
    end
  end

  describe '#hostname_proc' do
    it 'does not provide a container hostname if no override is given' do
      expect(test_deploy).to receive(:fetch).with(:container_hostname).and_return nil
      expect(test_deploy.hostname_proc).to be_nil
    end

    it 'provides container hostname if an override string is given' do
      expect(test_deploy).to receive(:fetch).with(:container_hostname).and_return 'example.com'
      expect(test_deploy.hostname_proc.call('foo')).to eq('example.com')
    end

    context 'container_hostname is overridden with a proc' do
      it 'provides a container hostname by executing the proc given' do
        expect(test_deploy).to receive(:fetch).with(:container_hostname).and_return ->(s) { "container.#{s}" }
        expect(test_deploy.hostname_proc.call('example.com')).to eq('container.example.com')
      end
    end
  end

  describe '#start_new_container' do
    let(:bindings) { {'80/tcp'=>[{'HostIp'=>'0.0.0.0', 'HostPort'=>'80'}]} }
    let(:env)      { { 'FOO' => 'BAR' } }
    let(:volumes)  { ['/foo:/bar'] }
    let(:command)  { ['/bin/echo', 'hi'] }

    it 'ultimately asks the server object to do the work' do
      service = double(:Service, name: :centurion, build_config: {"Image" => "abcdef"}, build_host_config: {})
      restart_policy = double(:RestartPolicy)

      expect(server).to receive(:create_container).with({"Image" => "abcdef"}, :centurion).and_return(container)

      expect(server).to receive(:start_container)
      expect(server).to receive(:inspect_container)

      new_container = test_deploy.start_new_container(server, service, restart_policy)
      expect(new_container).to eq(container)
    end
  end

  describe '#launch_console' do
    it 'starts the console' do
      service = double(:Service, name: :centurion, build_console_config: {"Image" => "abcdef"}, build_host_config: {})

      expect(server).to receive(:create_container).with({"Image" => "abcdef"}, :centurion).and_return(container)
      expect(server).to receive(:start_container)

      test_deploy.launch_console(server, service)
      expect(server).to have_received(:attach).with(container_id)
    end
  end
end
