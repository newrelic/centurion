require_relative 'docker_server_group'
require 'uri'

module Centurion::DeployDSL
  class PerHostConfiguration
    include Centurion::DeployDSL

    attr_reader :params

    def initialize(hostname)
      @params = {}
      set(:host, hostname)
    end

    def set(key, value)
      @params[key] = value
    end

    def fetch(key, default)
      @params[key] || default
    end
  end

  def on_each_docker_host(&block)
    global_config = env[current_environment]

    fetch(:per_host_configs, []).each do |host_config|
      config = global_config.merge(host_config)
      host = Centurion::DockerServer.new(config.fetch(:host), fetch(:docker_path), build_tls_params)
      info "----- Connecting to Docker on #{config.fetch(:host)} -----"
      block.call(host, config)
    end

    fetch(:hosts, []).each do |host|
      host = Centurion::DockerServer.new(host, fetch(:docker_path), build_tls_params)
      info "----- Connecting to Docker on #{host} -----"
      block.call(host, global_config)
    end
  end

  def env_vars(new_vars)
    current = fetch(:env_vars, {})
    new_vars.each_pair do |new_key, new_value|
      current[new_key.to_s] = new_value.to_s
    end
    set(:env_vars, current)
  end

  def host(hostname, &block)
    if block
      per_host = PerHostConfiguration.new(hostname)
      per_host.instance_exec(&block)
      configurations = fetch(:per_host_configs, [])
      configurations << per_host.params
      set(:per_host_configs, configurations)
    else
      current = fetch(:hosts, [])
      current << hostname
      set(:hosts, current)
    end
  end

  def memory(memory)
    set(:memory, memory)
  end

  def cpu_shares(cpu_shares)
    set(:cpu_shares, cpu_shares)
  end

  def command(command)
    set(:command, command)
  end

  def localhost
    # DOCKER_HOST is like 'tcp://127.0.0.1:2375'
    docker_host_uri = URI.parse(ENV['DOCKER_HOST'] || "tcp://127.0.0.1")
    host_and_port = [docker_host_uri.host, docker_host_uri.port].compact.join(':')
    host(host_and_port)
  end

  def host_port(port, options)
    validate_options_keys(options, [ :host_ip, :container_port, :type ])
    require_options_keys(options,  [ :container_port ])

    add_to_bindings(
      options[:host_ip],
      options[:container_port],
      port,
      options[:type] || 'tcp'
    )
  end

  def public_port_for(port_bindings)
    # {'80/tcp'=>[{'HostIp'=>'0.0.0.0', 'HostPort'=>'80'}]}
    first_port_binding = port_bindings.values.first
    first_port_binding.first['HostPort']
  end

  def host_volume(volume, options)
    validate_options_keys(options, [ :container_volume ])
    require_options_keys(options,  [ :container_volume ])

    binds            = fetch(:binds, [])
    container_volume = options[:container_volume]

    binds << "#{volume}:#{container_volume}"
    set(:binds, binds)
  end

  def get_current_tags_for(image)
    build_server_group.inject([]) do |memo, target_server|
      tags = target_server.current_tags_for(image)
      memo += [{ server: target_server.hostname, tags: tags }] if tags
      memo
    end
  end

  def registry(type)
    set(:registry, type.to_s)
  end

  def health_check(method)
   abort("Health check expects a callable (lambda, proc, method), but #{method.class} was specified")  unless method.respond_to?(:call)
   set(:health_check, method)
  end

  private

  def build_server_group
    hosts = fetch(:hosts, []) + fetch(:per_host_configs, []).map(&:host)
    Centurion::DockerServerGroup.new(hosts, fetch(:docker_path), build_tls_params)
  end

  def add_to_bindings(host_ip, container_port, port, type='tcp')
    set(:port_bindings, fetch(:port_bindings, {}).tap do |bindings|
      binding = { 'HostPort' => port.to_s }.tap do |b|
        b['HostIp'] = host_ip if host_ip
      end
      bindings["#{container_port.to_s}/#{type}"] = [ binding ]
      bindings
    end)
  end

  def validate_options_keys(options, valid_keys)
    unless options.keys.all? { |k| valid_keys.include?(k) }
      raise ArgumentError.new('Options passed with invalid key!')
    end
  end

  def require_options_keys(options, required_keys)
    missing = required_keys.reject { |k| options.keys.include?(k) }

    unless missing.empty?
      raise ArgumentError.new("Options must contain #{missing.inspect}")
    end
  end

  def tls_paths_available?
    Centurion::DockerViaCli.tls_keys.all? { |key| fetch(key).present? }
  end

  def build_tls_params
    return {} unless fetch(:tlsverify)
    {
      tls: fetch(:tlsverify || tls_paths_available?),
      tlscacert: fetch(:tlscacert),
      tlscert: fetch(:tlscert),
      tlskey: fetch(:tlskey)
    }
  end
end
