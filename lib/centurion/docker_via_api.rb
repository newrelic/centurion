require 'excon'
require 'json'
require 'uri'

module Centurion; end

class Centurion::DockerViaApi
  def initialize(hostname, port)
    @base_uri = "http://#{hostname}:#{port}"

    configure_excon_globally
  end

  def ps(options={})
    path = "/v1.7/containers/json"
    path += "?all=1" if options[:all]
    response = Excon.get(@base_uri + path)

    raise unless response.status == 200
    JSON.load(response.body)
  end

  def inspect_image(image, tag = "latest")
    repository = "#{image}:#{tag}"
    path       = "/v1.7/images/#{repository}/json"

    response = Excon.get(
      @base_uri + path,
      :headers => {'Accept' => 'application/json'}
    )
    raise response.inspect unless response.status == 200
    JSON.load(response.body)
  end

  def old_containers_for_port(host_port)
    old_containers = ps(all: true).select do |container|
      container["Status"] =~ /^(Exit |Exited)/
    end.select do |container|
      inspected = inspect_container container["Id"]
      container_listening_on_port?(inspected, host_port)
    end
    old_containers
  end

  def remove_container(container_id)
    path = "/v1.7/containers/#{container_id}"
    response = Excon.delete(
      @base_uri + path,
    )
    raise response.inspect unless response.status == 204
    true
  end

  def stop_container(container_id, timeout = 30)
    path = "/v1.7/containers/#{container_id}/stop?t=#{timeout}"
    response = Excon.post(
      @base_uri + path,
    )
    raise response.inspect unless response.status == 204
    true
  end

  def create_container(configuration)
    path = "/v1.10/containers/create"
    response = Excon.post(
      @base_uri + path,
      :body => configuration.to_json,
      :headers => { "Content-Type" => "application/json" }
    )
    raise response.inspect unless response.status == 201
    JSON.load(response.body)
  end

  def start_container(container_id, configuration)
    path = "/v1.10/containers/#{container_id}/start"
    response = Excon.post(
      @base_uri + path,
      :body => configuration.to_json,
      :headers => { "Content-Type" => "application/json" }
    )
    case response.status
    when 204
      true
    when 500
      fail "Failed to start container! \"#{response.body}\""
    else
      raise response.inspect
    end
  end

  def inspect_container(container_id)
    path = "/v1.7/containers/#{container_id}/json"
    response = Excon.get(
      @base_uri + path,
    )
    raise response.inspect unless response.status == 200
    JSON.load(response.body)
  end

  private

  # use on result of inspect container, not on an item in a list
  def container_listening_on_port?(container, port)
    port_bindings = container['HostConfig']['PortBindings']
    return false unless port_bindings

    port_bindings.values.flatten.compact.any? do |port_binding|
      port_binding['HostPort'].to_i == port.to_i
    end
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
