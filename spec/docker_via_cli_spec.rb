require 'spec_helper'
require 'centurion/docker_via_cli'

describe Centurion::DockerViaCli do
  let(:docker_path) { 'docker' }

  context 'without TLS certificates' do
    let(:docker_via_cli) { Centurion::DockerViaCli.new('host1', 2375, docker_path) }
    it 'pulls the latest image given its name' do
      expect(docker_via_cli).to receive(:echo).
                                with("docker -H=tcp://host1:2375 pull foo:latest")
      docker_via_cli.pull('foo')
    end

    it 'pulls an image given its name & tag' do
      expect(docker_via_cli).to receive(:echo).
                                with("docker -H=tcp://host1:2375 pull foo:bar")
      docker_via_cli.pull('foo', 'bar')
    end

    it 'tails logs on a container' do
      id = '12345abcdef'
      expect(docker_via_cli).to receive(:echo).
                                with("docker -H=tcp://host1:2375 logs -f #{id}")
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
  context 'with TLS certificates' do
    let(:tls_args) { { tls: true, tlscacert: '/certs/ca.pem',
                       tlscert: '/certs/cert.pem', tlskey: '/certs/key.pem' } }
    let(:docker_via_cli) { Centurion::DockerViaCli.new('host1', 2375,
                                                       docker_path, tls_args) }
    it 'pulls the latest image given its name' do
      expect(docker_via_cli).to receive(:echo).
                                with('docker -H=tcp://host1:2375 ' \
                                     '--tlsverify ' \
                                     '--tlscacert=/certs/ca.pem ' \
                                     '--tlscert=/certs/cert.pem ' \
                                     '--tlskey=/certs/key.pem pull foo:latest')
      docker_via_cli.pull('foo')
    end

    it 'pulls an image given its name & tag' do
      expect(docker_via_cli).to receive(:echo).
                                with('docker -H=tcp://host1:2375 ' \
                                     '--tlsverify ' \
                                     '--tlscacert=/certs/ca.pem ' \
                                     '--tlscert=/certs/cert.pem ' \
                                     '--tlskey=/certs/key.pem pull foo:bar')
      docker_via_cli.pull('foo', 'bar')
    end

    it 'tails logs on a container' do
      id = '12345abcdef'
      expect(docker_via_cli).to receive(:echo).
                                with('docker -H=tcp://host1:2375 ' \
                                     '--tlsverify ' \
                                     '--tlscacert=/certs/ca.pem ' \
                                     '--tlscert=/certs/cert.pem ' \
                                     "--tlskey=/certs/key.pem logs -f #{id}")
      docker_via_cli.tail(id)
    end

    it 'attach to a container' do
      id = '12345abcdef'
      expect(docker_via_cli).to receive(:echo).
                                with('docker -H=tcp://host1:2375 ' \
                                     '--tlsverify ' \
                                     '--tlscacert=/certs/ca.pem ' \
                                     '--tlscert=/certs/cert.pem ' \
                                     "--tlskey=/certs/key.pem attach #{id}")
      docker_via_cli.attach(id)
    end
  end
end
