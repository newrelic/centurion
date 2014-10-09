require 'pty'
require_relative 'logging'

module Centurion; end

class Centurion::DockerViaCli
  include Centurion::Logging

  def initialize(hostname, port, docker_path)
    @docker_host = "tcp://#{hostname}:#{port}"
    @docker_path = docker_path
  end

  def pull(image, tag='latest')
    info "Using CLI to pull"
    echo("#{@docker_path} -H=#{@docker_host} pull #{image}:#{tag}")
  end

  def tail(container_id)
    info "Tailing the logs on #{container_id}"
    echo("#{@docker_path} -H=#{@docker_host} logs -f #{container_id}")
  end

  def attach(container_id)
    Process.exec("#{@docker_path} -H=#{@docker_host} attach #{container_id}")
  end
end
