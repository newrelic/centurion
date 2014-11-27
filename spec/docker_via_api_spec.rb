require 'spec_helper'
require 'centurion/docker_via_api'

describe Centurion::DockerViaApi do
  let(:hostname) { 'example.com' }
  let(:port) { '2375' }
  let(:api) { Centurion::DockerViaApi.new(hostname, port) }
  let(:excon_uri) { "http://#{hostname}:#{port}/" }
  let(:json_string) { '[{ "Hello": "World" }]' }
  let(:json_value) { JSON.load(json_string) }
  let(:inspected_containers) do
    [
      {"Id" => "123", "Status" => "Exit 0"},
      {"Id" => "456", "Status" => "Running blah blah"},
      {"Id" => "789", "Status" => "Exited 1 mins ago"},
    ]
  end

  it 'lists processes' do
    expect(Excon).to receive(:get).
                     with(excon_uri + "v1.7" + "/containers/json").
                     and_return(double(body: json_string, status: 200))
    expect(api.ps).to eq(json_value)
  end

  it 'lists all processes' do
    expect(Excon).to receive(:get).
                     with(excon_uri + "v1.7" + "/containers/json?all=1").
                     and_return(double(body: json_string, status: 200))
    expect(api.ps(all: true)).to eq(json_value)
  end

  it 'inspects an image' do
    expect(Excon).to receive(:get).
                     with(excon_uri + "v1.7" + "/images/foo:bar/json",
                          headers: {'Accept' => 'application/json'}).
                     and_return(double(body: json_string, status: 200))
    expect(api.inspect_image('foo', 'bar')).to eq(json_value)
  end

  it 'creates a container' do
    configuration_as_json = double
    configuration = double(:to_json => configuration_as_json)
    expect(Excon).to receive(:post).
                         with(excon_uri + "v1.10" + "/containers/create",
                              query: nil,
                              body: configuration_as_json,
                              headers: {'Content-Type' => 'application/json'}).
                         and_return(double(body: json_string, status: 201))
    api.create_container(configuration)
  end

  it 'creates a container with a name' do
    configuration_as_json = double
    configuration = double(:to_json => configuration_as_json)
    expect(Excon).to receive(:post).
                         with(excon_uri + "v1.10" + "/containers/create",
                              query: {:name => match(/^app1-[a-f0-9]+$/)},
                              body: configuration_as_json,
                              headers: {'Content-Type' => 'application/json'}).
                         and_return(double(body: json_string, status: 201))
    api.create_container(configuration, 'app1')
  end

  it 'starts a container' do
    configuration_as_json = double
    configuration = double(:to_json => configuration_as_json)
    expect(Excon).to receive(:post).
                         with(excon_uri + "v1.10" + "/containers/12345/start",
                              body: configuration_as_json,
                              headers: {'Content-Type' => 'application/json'}).
                         and_return(double(body: json_string, status: 204))
    api.start_container('12345', configuration)
  end

  it 'stops a container' do
    expect(Excon).to receive(:post).
                     with(excon_uri + "v1.7" + "/containers/12345/stop?t=300").
                     and_return(double(status: 204))
    api.stop_container('12345', 300)
  end

  it 'stops a container with a custom timeout' do
    expect(Excon).to receive(:post).
                     with(excon_uri + "v1.7" + "/containers/12345/stop?t=30").
                     and_return(double(status: 204))
    api.stop_container('12345')
  end

  it 'inspects a container' do
    expect(Excon).to receive(:get).
                         with(excon_uri + "v1.7" + "/containers/12345/json").
                         and_return(double(body: json_string, status: 200))
    expect(api.inspect_container('12345')).to eq(json_value)
  end

  it 'removes a container' do
    expect(Excon).to receive(:delete).
                         with(excon_uri + "v1.7" + "/containers/12345").
                         and_return(double(status: 204))
    expect(api.remove_container('12345')).to eq(true)
  end

  it 'lists old containers for a port' do
    expect(Excon).to receive(:get).
                         with(excon_uri + "v1.7" + "/containers/json?all=1").
                         and_return(double(body: inspected_containers.to_json, status: 200))
    expect(Excon).to receive(:get).
                         with(excon_uri + "v1.7" + "/containers/123/json").
                         and_return(double(body: inspected_container_on_port("123", 8485).to_json, status: 200))
    expect(Excon).to receive(:get).
                         with(excon_uri + "v1.7" + "/containers/789/json").
                         and_return(double(body: inspected_container_on_port("789", 8486).to_json, status: 200))

    expect(api.old_containers_for_port(8485)).to eq([{"Id" => "123", "Status" => "Exit 0"}])
  end

  def inspected_container_on_port(id, port)
    {
      "Id" => id.to_s,
      "HostConfig" => {
        "PortBindings" => {
          "80/tcp" => [
            "HostIp" => "0.0.0.0",
            "HostPort" => port.to_s
          ]
        }
      }
    }
  end
end
