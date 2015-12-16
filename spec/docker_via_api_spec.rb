require 'spec_helper'
require 'centurion/docker_via_api'

describe Centurion::DockerViaApi do
  let(:hostname) { 'example.com' }
  let(:port) { '2375' }
  let(:api_version) { '1.12' }
  let(:json_string) { '[{ "Hello": "World" }]' }
  let(:json_value) { JSON.load(json_string) }

  context 'without TLS certificates' do
    let(:excon_uri) { "http://#{hostname}:#{port}/" }
    let(:api) { Centurion::DockerViaApi.new(hostname, port, {}, api_version) }

    it 'lists processes' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/containers/json", {}).
                       and_return(double(body: json_string, status: 200))
      expect(api.ps).to eq(json_value)
    end

    it 'lists all processes' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/containers/json?all=1", {}).
                       and_return(double(body: json_string, status: 200))
      expect(api.ps(all: true)).to eq(json_value)
    end

    it 'creates a container' do
      configuration_as_json = double
      configuration = double(to_json: configuration_as_json)
      expect(Excon).to receive(:post).
                           with(excon_uri + "v#{api_version}/containers/create",
                                query: nil,
                                body: configuration_as_json,
                                headers: {'Content-Type' => 'application/json'}).
                           and_return(double(body: json_string, status: 201))
      api.create_container(configuration)
    end

    it 'creates a container with a name' do
      configuration_as_json = double
      configuration = double(to_json: configuration_as_json)
      expect(Excon).to receive(:post).
                           with(excon_uri + "v#{api_version}/containers/create",
                                query: { name: match(/^app1-[a-f0-9]+$/) },
                                body: configuration_as_json,
                                headers: {'Content-Type' => 'application/json'}).
                           and_return(double(body: json_string, status: 201))
      api.create_container(configuration, 'app1')
    end

    it 'starts a container' do
      configuration_as_json = double
      configuration = double(to_json: configuration_as_json)
      expect(Excon).to receive(:post).
                           with(excon_uri + "v#{api_version}/containers/12345/start",
                                body: configuration_as_json,
                                headers: {'Content-Type' => 'application/json'}).
                           and_return(double(body: json_string, status: 204))
      api.start_container('12345', configuration)
    end

    it 'stops a container' do
      expect(Excon).to receive(:post).
                       with(excon_uri + "v#{api_version}/containers/12345/stop?t=300", {}).
                       and_return(double(status: 204))
      api.stop_container('12345', 300)
    end

    it 'stops a container with a custom timeout' do
      expect(Excon).to receive(:post).
                       with(excon_uri + "v#{api_version}/containers/12345/stop?t=30", {}).
                       and_return(double(status: 204))
      api.stop_container('12345')
    end

    it 'restarts a container' do
      expect(Excon).to receive(:post).
                          with(excon_uri + "v#{api_version}/containers/12345/restart?t=30", {}).
                          and_return(double(body: json_string, status: 204))
      api.restart_container('12345')
    end

    it 'restarts a container with a custom timeout' do
      expect(Excon).to receive(:post).
                          with(excon_uri + "v#{api_version}/containers/12345/restart?t=300", {}).
                          and_return(double(body: json_string, status: 204))
      api.restart_container('12345', 300)
    end

    it 'inspects a container' do
      expect(Excon).to receive(:get).
                           with(excon_uri + "v#{api_version}/containers/12345/json", {}).
                           and_return(double(body: json_string, status: 200))
      expect(api.inspect_container('12345')).to eq(json_value)
    end

    it 'removes a container' do
      expect(Excon).to receive(:delete).
                           with(excon_uri + "v#{api_version}/containers/12345", {}).
                           and_return(double(status: 204))
      expect(api.remove_container('12345')).to eq(true)
    end

    it 'inspects an image' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/images/foo:bar/json",
                            headers: {'Accept' => 'application/json'}).
                       and_return(double(body: json_string, status: 200))
      expect(api.inspect_image('foo', 'bar')).to eq(json_value)
    end

  end

  context 'with TLS certificates' do
    let(:excon_uri) { "https://#{hostname}:#{port}/" }
    let(:tls_args)  { { tls: true, tlscacert: '/certs/ca.pem',
                       tlscert: '/certs/cert.pem', tlskey: '/certs/key.pem' } }
    let(:api)       { Centurion::DockerViaApi.new(hostname, port, tls_args) }

    it 'lists processes' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/containers/json",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                       and_return(double(body: json_string, status: 200))
      expect(api.ps).to eq(json_value)
    end

    it 'lists all processes' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/containers/json?all=1",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                       and_return(double(body: json_string, status: 200))
      expect(api.ps(all: true)).to eq(json_value)
    end

    it 'inspects an image' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/images/foo:bar/json",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem',
                            headers: {'Accept' => 'application/json'}).
                       and_return(double(body: json_string, status: 200))
      expect(api.inspect_image('foo', 'bar')).to eq(json_value)
    end

    it 'creates a container' do
      configuration_as_json = double
      configuration = double(to_json: configuration_as_json)
      expect(Excon).to receive(:post).
                           with(excon_uri + "v#{api_version}/containers/create",
                                client_cert: '/certs/cert.pem',
                                client_key: '/certs/key.pem',
                                query: nil,
                                body: configuration_as_json,
                                headers: {'Content-Type' => 'application/json'}).
                           and_return(double(body: json_string, status: 201))
      api.create_container(configuration)
    end

    it 'starts a container' do
      configuration_as_json = double
      configuration = double(to_json: configuration_as_json)
      expect(Excon).to receive(:post).
                           with(excon_uri + "v#{api_version}/containers/12345/start",
                                client_cert: '/certs/cert.pem',
                                client_key: '/certs/key.pem',
                                body: configuration_as_json,
                                headers: {'Content-Type' => 'application/json'}).
                           and_return(double(body: json_string, status: 204))
      api.start_container('12345', configuration)
    end

    it 'stops a container' do
      expect(Excon).to receive(:post).
                       with(excon_uri + "v#{api_version}/containers/12345/stop?t=300",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                       and_return(double(status: 204))
      api.stop_container('12345', 300)
    end

    it 'stops a container with a custom timeout' do
      expect(Excon).to receive(:post).
                       with(excon_uri + "v#{api_version}/containers/12345/stop?t=30",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                       and_return(double(status: 204))
      api.stop_container('12345')
    end

    it 'restarts a container' do
      expect(Excon).to receive(:post).
                        with(excon_uri + "v#{api_version}/containers/12345/restart?t=30",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                        and_return(double(body: json_string, status: 204))
      api.restart_container('12345')
    end

    it 'restarts a container with a custom timeout' do
      expect(Excon).to receive(:post).
                        with(excon_uri + "v#{api_version}/containers/12345/restart?t=300",
                            client_cert: '/certs/cert.pem',
                            client_key: '/certs/key.pem').
                        and_return(double(body: json_string, status: 204))
      api.restart_container('12345', 300)
    end

    it 'inspects a container' do
      expect(Excon).to receive(:get).
                           with(excon_uri + "v#{api_version}/containers/12345/json",
                                client_cert: '/certs/cert.pem',
                                client_key: '/certs/key.pem').
                           and_return(double(body: json_string, status: 200))
      expect(api.inspect_container('12345')).to eq(json_value)
    end

    it 'removes a container' do
      expect(Excon).to receive(:delete).
                           with(excon_uri + "v#{api_version}/containers/12345",
                                client_cert: '/certs/cert.pem',
                                client_key: '/certs/key.pem').
                           and_return(double(status: 204))
      expect(api.remove_container('12345')).to eq(true)
    end
  end

   context 'with default TLS certificates' do
    let(:excon_uri) { "https://#{hostname}:#{port}/" }
    let(:tls_args)  { { tls: true } }
    let(:api)       { Centurion::DockerViaApi.new(hostname, port, tls_args) }

    it 'lists processes' do
      expect(Excon).to receive(:get).
                       with(excon_uri + "v#{api_version}/containers/json",
                            client_cert: File.expand_path('~/.docker/cert.pem'),
                            client_key: File.expand_path('~/.docker/key.pem')).
                       and_return(double(body: json_string, status: 200))
      expect(api.ps).to eq(json_value)
    end
  end
end
