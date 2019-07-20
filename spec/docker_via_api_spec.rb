require 'spec_helper'
require 'centurion/docker_via_api'

describe Centurion::DockerViaApi do
  let(:hostname) { 'example.com' }
  let(:port) { 2375 }
  let(:api_version) { '1.12' }
  let(:json_string) { '[{ "Hello": "World" }]' }
  let(:json_value) { JSON.load(json_string) }

  shared_examples "docker API" do
    it 'lists processes' do
      Excon.stub(base_req.merge(method: :get, path: '/v1.12/containers/json'), {body: json_string, status: 200})
      expect(api.ps).to eq(json_value)
    end

    it 'lists all processes' do
      Excon.stub(base_req.merge(method: :get, path: '/v1.12/containers/json?all=1'), {body: json_string, status: 200})
      expect(api.ps(all: true)).to eq(json_value)
    end

    it 'creates a container' do
      configuration_as_json = 'body'
      configuration = double(to_json: configuration_as_json)
      Excon.stub(base_req.merge(
        method: :post,
        path: '/v1.12/containers/create',
        body: configuration_as_json,
        headers: {'Content-Type' => 'application/json'}
      ),
                 {body: json_string, status: 201})
      api.create_container(configuration)
    end

    it 'creates a container with a name' do
      configuration_as_json = 'body'
      configuration = double(to_json: configuration_as_json)
      Excon.stub(base_req.merge(
        method: :post,
        path: '/v1.12/containers/create',
        query: /^name=app1-[a-f0-9]+$/,
        body: configuration_as_json,
        headers: {'Content-Type' => 'application/json'}
      ),
      {body: json_string, status: 201})
      api.create_container(configuration, 'app1')
    end

    it 'starts a container' do
      configuration_as_json = 'body'
      configuration = double(to_json: configuration_as_json)
      Excon.stub(base_req.merge(
        method: :post,
        path: '/v1.12/containers/12345/start',
        body: configuration_as_json,
        headers: {'Content-Type' => 'application/json'}
      ),
      {body: json_string, status: 204})
      api.start_container('12345', configuration)
    end

    it 'stops a container' do
      Excon.stub(base_req.merge(method: :post, path: '/v1.12/containers/12345/stop?t=300', read_timeout: 420), {status: 204})
      api.stop_container('12345', 300)
    end

    it 'stops a container with a custom timeout' do
      Excon.stub(base_req.merge(method: :post, path: '/v1.12/containers/12345/stop?t=30', read_timeout: 150), {status: 204})
      api.stop_container('12345')
    end

    it 'restarts a container' do
      Excon.stub(base_req.merge(method: :post, path: '/v1.12/containers/12345/restart?t=30', read_timeout: 150), {status: 204})
      api.restart_container('12345')
    end

    it 'restarts a container with a custom timeout' do
      Excon.stub(base_req.merge(method: :post, path: '/v1.12/containers/12345/restart?t=300', read_timeout: 420), {status: 204})
      api.restart_container('12345', 300)
    end

    it 'inspects a container' do
      Excon.stub(base_req.merge(method: :get, path: '/v1.12/containers/12345/json'), {body: json_string, status: 200})
      expect(api.inspect_container('12345')).to eq(json_value)
    end

    it 'removes a container' do
      Excon.stub(base_req.merge(method: :delete, path: '/v1.12/containers/12345'), {body: json_string, status: 204})
      expect(api.remove_container('12345')).to eq(true)
    end

    it 'inspects an image' do
      Excon.stub(base_req.merge(method: :get, path: '/v1.12/images/foo:bar/json', headers: {'Accept' => 'application/json'}), {body: json_string, status: 200})
      expect(api.inspect_image('foo', 'bar')).to eq(json_value)
    end
   end

  context 'without TLS certificates' do
    let(:api) { Centurion::DockerViaApi.new(hostname, port) }
    let(:base_req) { {hostname: hostname, port: port} }

    it_behaves_like 'docker API'
  end

  context 'with TLS certificates' do
    let(:tls_args)  { { tls: true, tlscacert: '/certs/ca.pem',
                       tlscert: '/certs/cert.pem', tlskey: '/certs/key.pem' } }
    let(:base_req) { {
      hostname: hostname,
      port: port,
      client_cert: '/certs/cert.pem',
      client_key: '/certs/key.pem',
    } }
    let(:api)       { Centurion::DockerViaApi.new(hostname, port, tls_args) }

    it_behaves_like 'docker API'
  end

  context 'with default TLS certificates' do
    let(:tls_args)  { { tls: true } }
    let(:base_req) { {
      hostname: hostname,
      port: port,
      client_cert: File.expand_path('~/.docker/cert.pem'),
      client_key: File.expand_path('~/.docker/key.pem'),
    } }
    let(:api)       { Centurion::DockerViaApi.new(hostname, port, tls_args) }

    it_behaves_like 'docker API'
  end

  context 'with a SSH connection' do
    let(:hostname) { 'hostname' }
    let(:port) { nil }
    let(:ssh_user) { 'myuser' }
    let(:ssh_log_level) { nil }
    let(:ssh_socket_heartbeat) { nil }
    let(:base_req) { {
      socket: '/tmp/socket/path'
    } }
    let(:api)       { Centurion::DockerViaApi.new(hostname, port, params) }
    let(:params) do
      p = { ssh: true}
      p[:ssh_user] = ssh_user if ssh_user
      p[:ssh_log_level] = ssh_log_level if ssh_log_level
      p[:ssh_socket_heartbeat] = ssh_socket_heartbeat if ssh_socket_heartbeat
      p
    end

    context 'with no log level' do
      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, ssh_user, nil, nil).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker API'
    end

    context 'with no user' do
      let(:ssh_user) { nil }

      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, nil, nil, nil).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker API'
    end

    context 'with a log level set' do
      let(:ssh_log_level) { Logger::DEBUG }

      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, ssh_user, Logger::DEBUG, nil).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker API'
    end

    context 'with a socket heartbeat set' do
      let(:ssh_socket_heartbeat) { 5 }

      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, ssh_user, nil, 5).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker API'
    end
  end
end
