require_relative 'docker_server'
require_relative 'logging'

module Centurion; end

class Centurion::DockerServerGroup
  include Enumerable
  include Centurion::Logging

  attr_reader :hosts

  def initialize(hosts, docker_path, tls_params = {}, api_version=nil)
    raise ArgumentError.new('Bad Host list!') if hosts.nil? || hosts.empty?
    api_version ||= '1.12'
    @hosts = hosts.map do |hostname|
      Centurion::DockerServer.new(hostname, docker_path, tls_params, api_version)
    end
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
