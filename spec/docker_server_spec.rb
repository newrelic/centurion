require 'spec_helper'
require 'centurion/docker_server'

describe Centurion::DockerServer do
  let(:host) { 'host1' }
  let(:docker_path) { 'docker' }
  let(:server) { Centurion::DockerServer.new(host, docker_path) }

  it 'knows its hostname' do
    expect(server.hostname).to eq('host1')
  end

  it 'knows its port' do
    expect(server.port).to eq('4243')
  end

  describe 'when host includes a port' do
    let(:host) { 'host2:4321' }
    it 'knows that port' do
      expect(server.port).to eq('4321')
    end
  end

  { docker_via_api: [:create_container, :inspect_container, :inspect_image,
                     :ps, :start_container, :stop_container],
    docker_via_cli: [:pull, :tail] }.each do |delegate, methods|
    methods.each do |method|
      it "delegates '#{method}' to #{delegate}" do
        dummy_result = double
        dummy_delegate = double(method => dummy_result)
        server.stub(delegate => dummy_delegate)
        expect(dummy_delegate).to receive(method)
        expect(server.send(method)).to be(dummy_result)
      end
    end
  end

  it 'returns tags associated with an image' do
    image_names = %w[target:latest target:production other:latest]
    server.stub(ps: image_names.map {|name| { 'Image' => name } })
    expect(server.current_tags_for('target')).to eq(%w[latest production])
  end
end
