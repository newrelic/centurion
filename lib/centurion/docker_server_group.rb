require_relative 'logging'
require 'docker'

module Centurion; end

class Centurion::DockerServerGroup
  include Enumerable
  include Centurion::Logging

  attr_reader :hosts
  
  def initialize(hosts)
    raise ArgumentError.new('Bad Host list!') if hosts.nil? || hosts.empty?
    @hosts = hosts.map do |hostname|
      hostname = "http://#{hostname}" unless hostname.start_with? "http"
      Docker::Connection.new(hostname, {})
    end
    configure_excon_globally
  end

  def each(&block)
    @hosts.each do |host|
      info "----- Connecting to Docker on #{URI.parse(host.url).host}:#{URI.parse(host.url).port} -----"
      block.call(host)
    end
  end

  def each_in_parallel(&block)
    threads = @hosts.map do |host|
      Thread.new { block.call(host) }
    end

    threads.each { |t| t.join }
  end

  def configure_excon_globally
    Excon.defaults[:connect_timeout] = 120
    Excon.defaults[:read_timeout]    = 120
    Excon.defaults[:write_timeout]   = 120
    Excon.defaults[:debug_request]   = true
    Excon.defaults[:debug_response]  = true
    Excon.defaults[:nonblock]        = false
    Excon.defaults[:tcp_nodelay]     = true
  end
end
