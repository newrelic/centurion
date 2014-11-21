require 'spec_helper'
require 'centurion/docker_server'
require 'centurion/docker_server_group'

describe Centurion::DockerServerGroup do
  let(:docker_path) { 'docker' }
  let(:group) { Centurion::DockerServerGroup.new(['host1', 'host2'], docker_path) }

  it 'takes a hostlist and instantiates DockerServers' do
    expect(group.hosts.length).to equal(2)
    expect(group.hosts.first).to be_a(Centurion::DockerServer)
    expect(group.hosts.last).to be_a(Centurion::DockerServer)
  end

  it 'implements Enumerable' do
    expect(group.methods).to be_a_kind_of(Enumerable)
  end

  it 'prints a friendly message to stderr when iterating' do
    expect(group).to receive(:info).with(/Connecting to Docker on host[0-9]/).twice

    group.each { |host| }
  end

  it 'can run parallel operations' do
    item = double('item').tap { |i| allow(i).to receive(:dummy_method) }
    expect(item).to receive(:dummy_method).twice

    expect { group.each_in_parallel { |host| item.dummy_method } }.not_to raise_error
  end
end
