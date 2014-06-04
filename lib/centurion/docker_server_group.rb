require_relative 'docker_server'
require_relative 'logging'

module Centurion; end

class Centurion::DockerServerGroup
  include Enumerable
  include Centurion::Logging

  attr_reader :hosts
  
  def initialize(hosts, docker_path)
    raise ArgumentError.new('Bad Host list!') if hosts.nil? || hosts.empty?
    @hosts = hosts.map { |hostname| Centurion::DockerServer.new(hostname, docker_path) }
  end

  def each(&block)
    @hosts.each do |host|
      info "----- Connecting to Docker on #{host.hostname} -----"
      block.call(host)
    end
  end

  def each_in_parallel(&block)
    threads = @hosts.map do |host|
      Thread.new { block.call(host) }
    end

    threads.each { |t| t.join }
  end
end
