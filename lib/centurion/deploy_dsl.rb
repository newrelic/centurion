require_relative 'docker_server_group'
require 'uri'

module Centurion::DeployDSL
  def on_each_docker_host(&block)
    Centurion::DockerServerGroup.new(fetch(:hosts, []), fetch(:docker_path)).tap do |hosts|
      hosts.each { |host| block.call(host) }
    end
  end

  def env_vars(new_vars)
    current = fetch(:env_vars, {})
    new_vars.each_pair do |new_key, new_value|
      current[new_key.to_s] = new_value.to_s
    end
    set(:env_vars, current)
  end

  def host(hostname)
    current = fetch(:hosts, [])
    current << hostname
    set(:hosts, current)
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
    hosts = Centurion::DockerServerGroup.new(fetch(:hosts), fetch(:docker_path))
    hosts.inject([]) do |memo, target_server|
      tags = target_server.current_tags_for(image)
      memo += [{ server: target_server.hostname, tags: tags }] if tags
      memo
    end
  end

  def registry(type)
    set(:registry, type)
  end

  private

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
end
