require 'excon'
require 'json'
require 'uri'
require 'securerandom'
require 'centurion/ssh'

module Centurion; end

class Centurion::DockerViaApi
  def initialize(hostname, port, connection_opts = {}, api_version = nil)
    @tls_args = default_tls_args(connection_opts[:tls]).merge(connection_opts.reject { |k, v| v.nil? }) # Required by tls_enable?
    if connection_opts[:ssh]
      @base_uri = hostname
      @ssh = true
      @connection_opts = connection_opts
    else
      @base_uri = "http#{'s' if tls_enable?}://#{hostname}:#{port}"
    end
    api_version ||= "/v1.12"
    @docker_api_version = api_version
    configure_excon_globally
  end

  def ps(options={})
    path = @docker_api_version + "/containers/json"
    path += "?all=1" if options[:all]
    response = with_excon {|e| e.get(path: path)}

    raise unless response.status == 200
    JSON.load(response.body)
  end

  def inspect_image(image, tag = "latest")
    repository = "#{image}:#{tag}"
    path       = @docker_api_version + "/images/#{repository}/json"

    response = with_excon do |e|
      e.get(
        path: path,
        headers: {'Accept' => 'application/json'}
      )
    end
    raise response.inspect unless response.status == 200
    JSON.load(response.body)
  end

  def remove_container(container_id)
    path = @docker_api_version + "/containers/#{container_id}"
    response = with_excon do |e|
      e.delete(
        path: path,
      )
    end
    raise response.inspect unless response.status == 204
    true
  end

  def stop_container(container_id, timeout = 30)
    path = @docker_api_version + "/containers/#{container_id}/stop?t=#{timeout}"
    response = with_excon do |e|
      e.post(
        path: path,
        # Wait for both the docker stop timeout AND the kill AND
        # potentially a very slow HTTP server.
        read_timeout: timeout + 120
      )
    end
    raise response.inspect unless response.status == 204
    true
  end

  def create_container(configuration, name = nil)
    path = @docker_api_version + "/containers/create"
    response = with_excon do |e|
      e.post(
        path: path,
        query: name ? "name=#{name}-#{SecureRandom.hex(7)}" : nil,
        body: configuration.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end
    raise response.inspect unless response.status == 201
    JSON.load(response.body)
  end

  def start_container(container_id, configuration)
    path = @docker_api_version + "/containers/#{container_id}/start"
    response = with_excon do |e|
      e.post(
        path: path,
        body: configuration.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end
    case response.status
    when 204
      true
    when 500
      fail "Failed to start container! \"#{response.body}\""
    else
      raise response.inspect
    end
  end

  def restart_container(container_id, timeout = 30)
    path = @docker_api_version + "/containers/#{container_id}/restart?t=#{timeout}"
    response = with_excon do |e|
      e.post(
        path: path,
        # Wait for both the docker stop timeout AND the kill AND
        # potentially a very slow HTTP server.
        read_timeout: timeout + 120
      )
    end
    case response.status
    when 204
      true
    when 404
      fail "Failed to start missing container! \"#{response.body}\""
    when 500
      fail "Failed to start existing container! \"#{response.body}\""
    else
      raise response.inspect
    end
  end

  def inspect_container(container_id)
    path = @docker_api_version + "/containers/#{container_id}/json"
    response = with_excon do |e|
      e.get(
        path: path,
      )
    end
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

  def tls_enable?
    @tls_args.is_a?(Hash) && @tls_args.size > 0
  end

  def tls_excon_arguments
    return {} unless [:tlscert, :tlskey].all? { |key| @tls_args.key?(key) }

    {
      client_cert: @tls_args[:tlscert],
      client_key: @tls_args[:tlskey]
    }
  end

  def configure_excon_globally
    Excon.defaults[:connect_timeout] = 120
    Excon.defaults[:read_timeout]    = 120
    Excon.defaults[:write_timeout]   = 120
    Excon.defaults[:debug_request]   = true
    Excon.defaults[:debug_response]  = true
    Excon.defaults[:nonblock]        = false
    Excon.defaults[:tcp_nodelay]     = true
    Excon.defaults[:ssl_ca_file]     = @tls_args[:tlscacert]
    Excon.defaults[:ssl_verify_peer] = false
  end

  def default_tls_args(tls_enabled)
    if tls_enabled
      {
          tlscacert: File.expand_path('~/.docker/ca.pem'),
          tlscert: File.expand_path('~/.docker/cert.pem'),
          tlskey: File.expand_path('~/.docker/key.pem')
      }
    else
      {}
    end
  end

  def with_excon(&block)
    if @ssh
      with_excon_via_ssh(&block)
    else
      yield Excon.new(@base_uri, tls_excon_arguments)
    end
  end

  def with_excon_via_ssh
    Centurion::SSH.with_docker_socket(@base_uri, @connection_opts[:ssh_user], @connection_opts[:ssh_log_level], @connection_opts[:ssh_socket_heartbeat]) do |socket|
      conn = Excon.new('unix:///', socket: socket)
      yield conn
    end
  end
end
