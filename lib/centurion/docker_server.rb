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
                 :remove_container, :restart_container
  def_delegators :docker_via_cli, :pull, :tail, :attach, :exec, :exec_it

  def initialize(host, docker_path, tls_params = {}, api_version=nil)
    @docker_path = docker_path
    @hostname, @port = host.split(':')
    @port ||= '2375'
    @tls_params = tls_params
    api_version ||= '1.12'
    @api_version = api_version
  end

  def current_tags_for(image)
    running_containers = ps.select { |c| c['Image'] =~ /#{image}/ }
    return [] if running_containers.empty?

    parse_image_tags_for(running_containers)
  end

  def find_containers_by_public_port(public_port, type='tcp')
    ps.select do |container|
      next unless container && container['Ports']
      container['Ports'].find do |port|
        port['PublicPort'] == public_port.to_i && port['Type'] == type
      end
    end
  end

  def find_containers_by_name(wanted_name)
    ps.select do |container|
      next unless container && container['Names']
      container['Names'].find do |name|
        name =~ /\A\/#{wanted_name}(-[a-f0-9]{14})?\Z/
      end
    end
  end

  def find_container_by_id(container_id)
    ps.find { |container| container && container['Id'] == container_id }
  end

  def old_containers_for_name(wanted_name)
    find_containers_by_name(wanted_name).select do |container|
      container["Status"] =~ /^(Exit |Exited)/
    end
  end

  private

  def docker_via_api
    @docker_via_api ||= Centurion::DockerViaApi.new(@hostname, @port,
                                                    @tls_params, @api_version)
  end

  def docker_via_cli
    @docker_via_cli ||= Centurion::DockerViaCli.new(@hostname, @port,
                                                    @docker_path, @tls_params)
  end

  def parse_image_tags_for(running_containers)
    running_container_names = running_containers.map { |c| c['Image'] }
    running_container_names.map { |name| name.split(/:/).last } # (image, tag)
  end
end
