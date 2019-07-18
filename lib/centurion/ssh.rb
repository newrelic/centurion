require 'net/ssh'
require 'sshkit'
require 'tempfile'

module Centurion; end

module Centurion::SSH
  extend self

  def with_docker_socket(hostname, user, log_level = nil, ssh_socket_heartbeat = nil)
    log_level ||= Logger::WARN

    with_sshkit(hostname, user) do
      with_ssh do |ssh|
        ssh.logger = Logger.new STDERR
        ssh.logger.level = log_level

        # Tempfile ensures permissions are 0600
        local_socket_path_file = Tempfile.new('docker_forward')
        local_socket_path = local_socket_path_file.path
        ssh.forward.local_socket(local_socket_path, '/var/run/docker.sock')

        t = Thread.new do
          yield local_socket_path
        end

        ssh.loop(ssh_socket_heartbeat) { t.alive? }
        ssh.forward.cancel_local_socket local_socket_path
        local_socket_path_file.delete
        t.value
      end
    end
  end

  def with_sshkit(hostname, user, &block)
    uri = hostname
    uri = "#{user}@#{uri}" if user
    host = SSHKit::Host.new uri
    SSHKit::Backend::Netssh.new(host, &block).run
  end
end
