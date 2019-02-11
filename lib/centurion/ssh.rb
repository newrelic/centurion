require 'net/ssh'
require 'sshkit'
require 'tempfile'

module Centurion; end

module Centurion::SSH
  extend self

  DOCKER_SOCKET_PATH = '/var/run/docker.sock'

  def with_docker_socket(hostname, user, log_level = nil)
    log_level ||= Logger::WARN

    with_sshkit(hostname, user) do
      with_ssh do |ssh|
        ssh.logger = Logger.new STDERR
        ssh.logger.level = log_level

        # Validate that we have access to the Docker socket before attempting to
        # forward it. This ensures a meaningful error message if we don't.
        if ssh.exec!("test -w '#{DOCKER_SOCKET_PATH}'").exitstatus != 0
          raise "Docker socket at '#{DOCKER_SOCKET_PATH}' was not writable by user '#{user}' on '#{hostname}'. Is this user in the 'docker' group?"
        end

        # Tempfile ensures permissions are 0600
        local_socket_path_file = Tempfile.new('docker_forward')
        local_socket_path = local_socket_path_file.path
        ssh.forward.local_socket(local_socket_path, DOCKER_SOCKET_PATH)

        t = Thread.new do
          yield local_socket_path
        end

        ssh.loop { t.alive? }
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
