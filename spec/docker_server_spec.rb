require 'spec_helper'
require 'centurion/docker_server'

describe Centurion::DockerServer do
  let(:host)   { 'host1' }
  let(:docker_path) { 'docker' }
  let(:server) { Centurion::DockerServer.new(host, docker_path) }
  let(:container) {
     {
       'Command' => '/bin/bash',
       'Created' => 1414797234,
       'Id'      => '28970c706db0f69716af43527ed926acbd82581e1cef5e4e6ff152fce1b79972',
       'Image'   => 'centurion-test:latest',
       'Names'   => ['/centurion-783aac4'],
       'Ports'   => [{'PrivatePort'=>80, 'Type'=>'tcp', 'IP'=>'0.0.0.0', 'PublicPort'=>23235}],
       'Status'  => 'Up 3 days'
     }
  }
  let(:ps)     { [ container, {}, nil ] }

  it 'knows its hostname' do
    expect(server.hostname).to eq('host1')
  end

  it 'knows its port' do
    expect(server.port).to eq('2375')
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
        allow(server).to receive(delegate).and_return(dummy_delegate)
        expect(dummy_delegate).to receive(method)
        expect(server.send(method)).to be(dummy_result)
      end
    end
  end

  it 'returns tags associated with an image' do
    image_names = %w[target:latest target:production other:latest]
    allow(server).to receive(:ps).and_return(image_names.map {|name| { 'Image' => name } })
    expect(server.current_tags_for('target')).to eq(%w[latest production])
  end

  context 'finding containers' do
    before do
      allow(server).to receive(:ps).and_return(ps)
    end

    it 'finds containers by port' do
      expect(server.find_containers_by_public_port(23235, 'tcp')).to eq([container])
    end

    it 'only returns correct matches by port' do
      expect(server.find_containers_by_public_port(1234, 'tcp')).to be_empty
    end

    it 'finds containers by name' do
      expect(server.find_containers_by_name('centurion')).to eq([container])
    end

    it 'only returns correct matches by name' do
      expect(server.find_containers_by_name('fbomb')).to be_empty
    end
  end
end
