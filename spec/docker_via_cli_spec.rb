require 'spec_helper'
require 'centurion/docker_via_cli'

describe Centurion::DockerViaCli do
  let(:docker_path) { 'docker' }

  shared_examples 'docker CLI' do
    it 'pulls the latest image given its name' do
      expect(Centurion::Shell).to receive(:echo).
                                with("docker #{prefix} pull foo:latest")
      docker_via_cli.pull('foo')
    end

    it 'pulls an image given its name & tag' do
      expect(Centurion::Shell).to receive(:echo).
                                with("docker #{prefix} pull foo:bar")
      docker_via_cli.pull('foo', 'bar')
    end

    it 'tails logs on a container' do
      id = '12345abcdef'
      expect(Centurion::Shell).to receive(:echo).
                                with("docker #{prefix} logs -f #{id}")
      docker_via_cli.tail(id)
    end

    it 'attach to a container' do
      id = '12345abcdef'
      expect(Centurion::Shell).to receive(:echo).
                                with("docker #{prefix} attach #{id}")
      docker_via_cli.attach(id)
    end

    it 'should print all chars when one thread is running' do
      expect(Centurion::Shell).to receive(:run_with_echo)

      allow(Thread).to receive(:list) {[double(status: 'run')]}

      docker_via_cli.pull('foo')
    end

    it 'should only print lines when multiple threads are running' do
      expect(Centurion::Shell).to receive(:run_without_echo)

      allow(Thread).to receive(:list) {[double(status: 'run'), double(status: 'run')]}

      docker_via_cli.pull('foo')
    end
  end

  context 'without TLS certificates' do
    let(:docker_via_cli) { Centurion::DockerViaCli.new('host1', 2375, docker_path) }
    let(:prefix) { "-H=tcp://host1:2375" }

    it_behaves_like 'docker CLI'
  end

  context 'with TLS certificates' do
    let(:tls_args) { { tls: true, tlscacert: '/certs/ca.pem',
                       tlscert: '/certs/cert.pem', tlskey: '/certs/key.pem' } }
    let(:docker_via_cli) { Centurion::DockerViaCli.new('host1', 2375,
                                                       docker_path, tls_args) }
    let(:prefix) { "-H=tcp://host1:2375 --tlsverify --tlscacert=/certs/ca.pem --tlscert=/certs/cert.pem --tlskey=/certs/key.pem" }

    it_behaves_like 'docker CLI'
  end

  context 'with a SSH connection' do
    let(:hostname) { 'host1' }
    let(:ssh_user) { 'myuser' }
    let(:ssh_log_level) { nil }
    let(:docker_via_cli) { Centurion::DockerViaCli.new(hostname, nil, docker_path, params) }
    let(:prefix) { "-H=unix:///tmp/socket/path" }
    let(:params) do
      p = { ssh: true}
      p[:ssh_user] = ssh_user if ssh_user
      p[:ssh_log_level] = ssh_log_level if ssh_log_level
      p
    end

    context 'with no log level' do
      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, ssh_user, nil).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker CLI'
    end

    context 'with no user' do
      let(:ssh_user) { nil }

      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, nil, nil).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker CLI'
    end

    context 'with a log level set' do
      let(:ssh_log_level) { Logger::DEBUG }

      before do
        expect(Centurion::SSH).to receive(:with_docker_socket).with(hostname, ssh_user, Logger::DEBUG).and_yield('/tmp/socket/path')
      end

      it_behaves_like 'docker CLI'
    end
  end
end
