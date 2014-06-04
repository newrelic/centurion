require 'pty'
require 'forwardable'

require_relative 'logging'
require_relative 'docker_via_api'
require_relative 'docker_via_cli'

module Centurion; end

class Centurion::DockerServer
  include Centurion::Logging
  extend Forwardable

  attr_reader :hostname, :port

  def_delegators :docker_via_api, :create_container, :inspect_container,
                 :inspect_image, :ps, :start_container, :stop_container,
                 :old_containers_for_port, :remove_container
  def_delegators :docker_via_cli, :pull, :tail, :attach

  def initialize(host, docker_path)
    @docker_path = docker_path
    @hostname, @port = host.split(':')
    @port ||= '4243'
  end

  def current_tags_for(image)
    running_containers = ps.select { |c| c['Image'] =~ /#{image}/ }
    return [] if running_containers.empty?

    parse_image_tags_for(running_containers)
  end

  def find_containers_by_public_port(public_port, type='tcp')
    ps.select do |container|
      if container['Ports']
        container['Ports'].find do |port|
          port['PublicPort'] == public_port.to_i && port['Type'] == type
        end
      end
    end
  end

  private

  def docker_via_api
    @docker_via_api ||= Centurion::DockerViaApi.new(@hostname, @port)
  end

  def docker_via_cli
    @docker_via_cli ||= Centurion::DockerViaCli.new(@hostname, @port, @docker_path)
  end

  def parse_image_tags_for(running_containers)
    running_container_names = running_containers.map { |c| c['Image'] }
    running_container_names.map { |name| name.split(/:/).last } # (image, tag)
  end
end
