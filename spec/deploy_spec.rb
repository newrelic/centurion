require 'centurion/deploy'
require 'centurion/deploy_dsl'
require 'centurion/logging'

describe Centurion::Deploy do
  let(:mock_ok_status)  { double('http_status_ok').tap { |s| s.stub(status: 200) } }
  let(:mock_bad_status) { double('http_status_ok').tap { |s| s.stub(status: 500) } }
  let(:server)          { double('docker_server').tap { |s| s.stub(hostname: 'host1'); s.stub(:attach) } }
  let(:port)            { 8484 }
  let(:container)       { { 'Ports' => [{ 'PublicPort' => port }, 'Created' => Time.now.to_i ], 'Id' => '21adfd2ef2ef2349494a', 'Names' => [ 'name1' ] } }
  let(:endpoint)        { '/status/check' }
  let(:test_deploy) do 
    Object.new.tap do |o| 
      o.send(:extend, Centurion::Deploy)
      o.send(:extend, Centurion::DeployDSL)
      o.send(:extend, Centurion::Logging)
    end
  end

  describe '#http_status_ok?' do
    it 'validates HTTP status checks when the response is good' do
      expect(Excon).to receive(:get).and_return(mock_ok_status)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_true
    end

    it 'identifies bad HTTP responses' do
      expect(Excon).to receive(:get).and_return(mock_bad_status)
      test_deploy.stub(:warn)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_false
    end

    it 'outputs the HTTP status when it is not OK' do
      expect(Excon).to receive(:get).and_return(mock_bad_status)
      expect(test_deploy).to receive(:warn).with(/Got HTTP status: 500/)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_false
    end

    it 'handles SocketErrors and outputs a message' do
      expect(Excon).to receive(:get).and_raise(Excon::Errors::SocketError.new(RuntimeError.new()))
      expect(test_deploy).to receive(:warn).with(/Failed to connect/)
      expect(test_deploy.http_status_ok?(server, port, endpoint)).to be_false
    end
  end

  describe '#container_up?' do
    it 'recognizes when no containers are running' do
      expect(server).to receive(:find_containers_by_public_port).and_return([])

      test_deploy.container_up?(server, port).should be_false
    end

    it 'complains when more than one container is bound to this port' do
      expect(server).to receive(:find_containers_by_public_port).and_return([1,2])
      expect(test_deploy).to receive(:error).with /More than one container/

      test_deploy.container_up?(server, port).should be_false
    end

    it 'recognizes when the container is actually running' do
      expect(server).to receive(:find_containers_by_public_port).and_return([container])
      expect(test_deploy).to receive(:info).with /Found container/

      test_deploy.container_up?(server, port).should be_true
    end
  end

  describe '#wait_for_http_status_ok?' do
    before do
      test_deploy.stub(:info)
    end

    it 'identifies that a container is up' do
      test_deploy.stub(:container_up? => true)
      test_deploy.stub(:http_status_ok? => true)

      test_deploy.wait_for_http_status_ok(server, port, '/foo', 'image_id', 'chaucer')
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
      expect(test_deploy).to have_received(:info).with('Container is up!')
    end

    it 'waits when the container is not yet up' do
      test_deploy.stub(:container_up? => false)
      test_deploy.stub(:error)
      test_deploy.stub(:warn)
      expect(test_deploy).to receive(:exit)
      expect(test_deploy).to receive(:sleep).with(0)
       
      test_deploy.wait_for_http_status_ok(server, port, '/foo', 'image_id', 'chaucer', 0, 1)
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
    end

    it 'waits when the HTTP status is not OK' do
      test_deploy.stub(:container_up? => true)
      test_deploy.stub(:http_status_ok? => false)
      test_deploy.stub(:error)
      test_deploy.stub(:warn)
      expect(test_deploy).to receive(:exit)
       
      test_deploy.wait_for_http_status_ok(server, port, '/foo', 'image_id', 'chaucer', 1, 0)
      expect(test_deploy).to have_received(:info).with(/Waiting for the port/)
    end
  end

  describe '#cleanup_containers' do
    it 'deletes all but two containers' do
      expect(server).to receive(:old_containers_for_port).with(port.to_s).and_return([
        {'Id' => '123', 'Names' => ['foo']},
        {'Id' => '456', 'Names' => ['foo']},
        {'Id' => '789', 'Names' => ['foo']},
        {'Id' => '0ab', 'Names' => ['foo']},
        {'Id' => 'cde', 'Names' => ['foo']},
      ])
      expect(server).to receive(:remove_container).with('789')
      expect(server).to receive(:remove_container).with('0ab')
      expect(server).to receive(:remove_container).with('cde')

      test_deploy.cleanup_containers(server, {'80/tcp' => [{'HostIp' => '0.0.0.0', 'HostPort' => port.to_s}]})
    end
  end

  describe '#stop_containers' do
    it 'calls stop_container on the right containers' do
      second_container = container.dup
      containers = [ container, second_container ]
      bindings = {'80/tcp'=>[{'HostIp'=>'0.0.0.0', 'HostPort'=>'80'}]}

      expect(server).to receive(:find_containers_by_public_port).and_return(containers)
      expect(test_deploy).to receive(:public_port_for).with(bindings).and_return('80')
      expect(server).to receive(:stop_container).with(container['Id']).once
      expect(server).to receive(:stop_container).with(second_container['Id']).once

      test_deploy.stop_containers(server, bindings)
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

  describe '#container_config_for' do
    it 'works with env_vars provided' do
      config = test_deploy.container_config_for(server, 'image_id', {}, 'FOO' => 'BAR')

      expect(config).to be_a(Hash)
      expect(config.keys).to match_array(%w{ Hostname Image Env ExposedPorts })
      expect(config['Env']).to eq(['FOO=BAR'])
    end

    it 'works without env_vars or port_bindings' do
      config = test_deploy.container_config_for(server, 'image_id')

      expect(config).to be_a(Hash)
      expect(config.keys).to match_array(%w{ Hostname Image })
    end

    it 'interpolates the hostname into env_vars' do
      config = test_deploy.container_config_for(server, 'image_id', {}, 'FOO' => '$DOCKER_HOSTNAME')

      expect(config['Env']).to eq(['FOO=host1'])
    end

    it 'handles mapping host volumes' do
      config = test_deploy.container_config_for(server, 'image_id', nil, nil, ["/tmp/foo:/tmp/chaucer"])

      expect(config).to be_a(Hash)
      expect(config.keys).to match_array(%w{ Hostname Image Volumes VolumesFrom })
      expect(config['Volumes']['/tmp/chaucer']).to eq({})
    end

    it "exposes all ports" do
      config = test_deploy.container_config_for(server, 'image_id', {1234 => 80, 9876 => 80})

      expect(config['ExposedPorts']).to be_a(Hash)
      expect(config['ExposedPorts'].keys).to eq [1234, 9876]
    end
  end

  describe '#start_new_container' do
    let(:bindings) { {'80/tcp'=>[{'HostIp'=>'0.0.0.0', 'HostPort'=>'80'}]} }

    it 'configures the container' do
      expect(test_deploy).to receive(:container_config_for).with(server, 'image_id', bindings, nil, {}).once
      test_deploy.stub(:start_container_with_config)

      test_deploy.start_new_container(server, 'image_id', bindings, {})
    end

    it 'starts the container' do
      expect(test_deploy).to receive(:start_container_with_config).with(server, {}, anything(), anything())

      test_deploy.start_new_container(server, 'image_id', bindings, {})
    end

    it 'ultimately asks the server object to do the work' do
      server.should_receive(:create_container).with(
        hash_including({'Image'=>'image_id', 'Hostname'=>'host1', 'ExposedPorts'=>{'80/tcp'=>{}}})
      ).and_return(container)

      server.should_receive(:start_container)
      server.should_receive(:inspect_container)

      new_container = test_deploy.start_new_container(server, 'image_id', bindings, {})
      expect(new_container).to eq(container)
    end
  end

  describe '#launch_console' do
    let(:bindings) { {'80/tcp'=>[{'HostIp'=>'0.0.0.0', 'HostPort'=>'80'}]} }

    it 'configures the container' do
      expect(test_deploy).to receive(:container_config_for).with(server, 'image_id', bindings, nil, {}).once
      test_deploy.stub(:start_container_with_config)

      test_deploy.start_new_container(server, 'image_id', bindings, {})
    end

    it 'augments the container_config' do
      expect(test_deploy).to receive(:start_container_with_config).with(server, {},
        anything(),
        hash_including('Cmd' => [ '/bin/bash' ], 'AttachStdin' => true , 'Tty' => true , 'OpenStdin' => true)
      ).and_return({'Id' => 'shakespeare'})

      test_deploy.launch_console(server, 'image_id', bindings, {})
    end

    it 'starts the console' do
      expect(test_deploy).to receive(:start_container_with_config).with(
        server, {}, anything(), anything()
      ).and_return({'Id' => 'shakespeare'})

      test_deploy.launch_console(server, 'image_id', bindings, {})
      expect(server).to have_received(:attach).with('shakespeare')
    end
  end
end
