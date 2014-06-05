require 'spec_helper'
require 'centurion/docker_via_cli'

describe Centurion::DockerViaCli do
  let(:docker_path) { 'docker' }
  let(:docker_via_cli) { Centurion::DockerViaCli.new('host1', 4243, docker_path) }

  it 'pulls the latest image given its name' do
    expect(docker_via_cli).to receive(:echo).
                              with("docker -H=tcp://host1:4243 pull foo:latest")
    docker_via_cli.pull('foo')
  end

  it 'pulls an image given its name & tag' do
    expect(docker_via_cli).to receive(:echo).
                              with("docker -H=tcp://host1:4243 pull foo:bar")
    docker_via_cli.pull('foo', 'bar')
  end

  it 'tails logs on a container' do
    id = '12345abcdef'
    expect(docker_via_cli).to receive(:echo).
                              with("docker -H=tcp://host1:4243 logs -f #{id}")
    docker_via_cli.tail(id)
  end

  it 'should print all chars when one thread is running' do
    expect(docker_via_cli).to receive(:run_with_echo)

    allow(Thread).to receive(:list) {[double(:status => 'run')]}

    docker_via_cli.pull('foo')
  end

  it 'should only print lines when multiple threads are running' do
    expect(docker_via_cli).to receive(:run_without_echo)

    allow(Thread).to receive(:list) {[double(:status => 'run'), double(:status => 'run')]}

    docker_via_cli.pull('foo')
  end
end
