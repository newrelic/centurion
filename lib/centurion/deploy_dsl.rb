require_relative 'docker_server_group'
require_relative 'docker_server'
require_relative 'service'
require 'uri'

module Centurion::DeployDSL
  def on_each_docker_host(&block)
    build_server_group.tap { |hosts| hosts.each { |host| block.call(host) } }
  end

  def on_first_docker_host(&block)
    build_server_group.tap { |hosts| block.call(hosts.first) }
  end

  def env_vars(new_vars)
    current = fetch(:env_vars, {})
    new_vars.each_pair do |new_key, new_value|
      current[new_key.to_s] = new_value.to_s
    end
    set(:env_vars, current)
  end

  def labels(new_labels)
    current = fetch(:labels, {})
    new_labels.each_pair do |new_key, new_value|
      current[new_key.to_s] = new_value.to_s
    end
    set(:labels, current)
  end

  def add_capability(new_cap_adds)
    if !valid_capability?(new_cap_adds)
      abort("Invalid capability addition #{new_cap_adds} specified.")
    end
    current = fetch(:cap_adds, [])
    set(:cap_adds, current << new_cap_adds)
  end

  def drop_capability(new_cap_drops)
    if !valid_capability?(new_cap_drops)
      abort("Invalid capability drop #{new_cap_drops} specified.")
    end
    current = fetch(:cap_drops, [])
    set(:cap_drops, current << new_cap_drops)
  end

  def host(hostname)
    current = fetch(:hosts, [])
    current << hostname
    set(:hosts, current)
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

  def ipc_mode(mode)
    set(:ipc_mode, mode)
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

    set(:port_bindings, fetch(:port_bindings, []).tap do |bindings|
      bindings << Centurion::Service::PortBinding.new(port, options[:container_port], options[:type] || 'tcp', options[:host_ip])
    end)
  end

  def network_mode(mode)
    if %w(bridge host).include?(mode) or mode =~ /container.*/
      set(:network_mode, mode)
    else
      abort("invalid value for network_mode: #{mode}, value must be one of 'bridge', 'host', or 'container:<name|id>'")
    end
  end

  def public_port_for(port_bindings)
    # port_bindings = [#<struct Centurion::Service::PortBinding
    #   host_port=17090,
    #   container_port=80,
    #   type="tcp",
    #   host_ip=nil>]
    port_bindings.first.host_port
  end

  def host_volume(volume, options)
    validate_options_keys(options, [ :container_volume ])
    require_options_keys(options,  [ :container_volume ])

    set(:binds, fetch(:binds, []).tap do |volumes|
      volumes << Centurion::Service::Volume.new(volume, options[:container_volume])
    end)
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

  def extra_host(ip, name)
    current = fetch(:extra_hosts, [])
    current.push("#{name}:#{ip}")
    set(:extra_hosts, current)
  end

  def defined_service
    Centurion::Service.from_env
  end

  def defined_health_check
    Centurion::HealthCheck.new(fetch(:health_check, method(:http_status_ok?)),
                               fetch(:status_endpoint, '/'),
                               fetch(:rolling_deploy_wait_time, 5),
                               fetch(:rolling_deploy_retries, 24))
  end

  def defined_restart_policy
    Centurion::Service::RestartPolicy.new(fetch(:restart_policy_name, 'on-failure'), fetch(:restart_policy_max_retry_count, 10))
  end

  def before_stopping_image(callback = nil, &block)
    collect_callback :before_stopping_image_callbacks, callback, &block
  end

  def after_image_started(callback = nil, &block)
    collect_callback :after_image_started_callbacks, callback, &block
  end

  private

  def collect_callback(name, callback = nil, &block)
    return unless callback || block
    abort('Callback expects a lambda, proc, or block') if callback && !callback.respond_to?(:call)
    callbacks = fetch(name, [])
    callbacks << (callback || block)
    set(name, callbacks)
  end

  def service_under_construction
    service = fetch(:service,
      Centurion::Service.from_hash(
        fetch(:project),
        image:    fetch(:image),
        hostname: fetch(:container_hostname),
        dns:      fetch(:custom_dns)
      )
    )
    set(:service, service)
  end


  def build_server_group
    hosts, docker_path = fetch(:hosts, []), fetch(:docker_path)
    Centurion::DockerServerGroup.new(hosts, docker_path, build_tls_params)
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

  def valid_capability?(capability)
    %w(ALL SETPCAP SYS_MODULE SYS_RAWIO SYS_PACCT SYS_ADMIN SYS_NICE
       SYS_RESOURCE SYS_TIME SYS_TTY_CONFIG MKNOD AUDIT_WRITE AUDIT_CONTROL
       MAC_OVERRIDE MAC_ADMIN NET_ADMIN SYSLOG CHOWN NET_RAW DAC_OVERRIDE FOWNER
       DAC_READ_SEARCH FSETID KILL SETGID SETUID LINUX_IMMUTABLE
       NET_BIND_SERVICE NET_BROADCAST IPC_LOCK IPC_OWNER SYS_CHROOT SYS_PTRACE
       SYS_BOOT LEASE SETFCAP WAKE_ALARM BLOCK_SUSPEND).include?(capability)
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
