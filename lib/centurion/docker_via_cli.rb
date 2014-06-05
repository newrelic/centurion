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

  private

  def echo(command)
    if Thread.list.find_all { |t| t.status == 'run' }.count > 1
      run_without_echo(command)
    else
      run_with_echo(command)
    end
  end

  def run_without_echo(command)
    IO.popen(command) do |io|
      io.each_line { |line| puts line }
    end
    unless $?.success?
      raise "The command failed with a non-zero exit status: #{$?.exitstatus}"
    end
  end

  def run_with_echo( command )
    $stdout.sync = true
    $stderr.sync = true
    IO.popen(command) do |io|
      io.each_char { |char| print char }
    end
    unless $?.success?
      raise "The command failed with a non-zero exit status: #{$?.exitstatus}"
    end
  end
end
