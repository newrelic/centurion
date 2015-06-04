require 'socket'

module Centurion
  class Service

    attr_accessor :command, :dns, :image, :name
    attr_reader :memory, :cpu_shares, :env_vars, :volumes, :port_bindings

    def initialize(name)
      @name = name
      @env_vars = {}
      @volumes = []
      @port_bindings = []
    end

    def self.from_hash(name, definition)
      Service.new(name).tap do |s|
        s.image    = definition[:image]
        s.dns      = definition[:dns]

        definition.fetch(:volumes, []).each do |port|
          s.add_volume(port[:host_volume], port[:container_volume])
        end

        definition.fetch(:port_bindings, []).each do |binding|
          s.add_port_bindings(
            binding[:host_port],
            binding[:container_port],
            binding[:type],
            binding[:host_ip]
          )
        end
      end
    end

    def add_env_vars(new_vars)
      @env_vars.merge!(new_vars)
    end

    def add_port_bindings(host_port, container_port, type = 'tcp', host_ip = nil)
      @port_bindings << PortBinding.new(host_port, container_port, type, host_ip)
    end

    def add_volume(host_volume, container_volume)
      @volumes << Volume.new(host_volume, container_volume)
    end

    def memory=(bytes)
      if !bytes || !is_a_uint64?(bytes)
    raise ArgumentError, "invalid value for cgroup memory constraint: #{bytes}, value must be a between 0 and 18446744073709551615"
      end
      @memory = bytes
    end

    def cpu_shares=(shares)
      if !shares || !is_a_uint64?(shares)
        raise ArgumentError, "invalid value for cgroup CPU constraint: #{shares}, value must be a between 0 and 18446744073709551615"
      end
      @cpu_shares = shares
    end

    def image=(image)
      @image = image
    end

    def build_config(server_hostname, &block)
      container_config = {}.tap do |c|
        c['Image'] = image
        c['Hostname'] = yield server_hostname if block_given?
        c['Cmd'] = command if command
        c['Memory'] = memory if memory
        c['CpuShares'] = cpu_shares if cpu_shares
      end

      unless port_bindings.empty?
        container_config['ExposedPorts'] = port_bindings.reduce({}) do |config, binding|
          config["#{binding.container_port}/#{binding.type}"] = {}
          config
        end
      end

      unless env_vars.empty?
        container_config['Env'] = env_vars.map do |k,v|
          "#{k}=#{interpolate_var(v, server_hostname)}"
        end
      end

      unless volumes.empty?
        container_config['Volumes'] = volumes.inject({}) do |memo, v|
          memo[v.container_volume] = {}
          memo
        end
        container_config['VolumesFrom'] = 'parent'
      end

      container_config
    end

    def build_host_config(restart_policy = nil)
      host_config = {}

      # Map some host volumes if needed
      host_config['Binds'] = volume_binds_config if volume_binds_config

      # Bind the ports
      host_config['PortBindings'] = port_bindings_config

      # DNS if specified
      host_config['Dns'] = dns if dns

      # Restart Policy
      if restart_policy
        host_config['RestartPolicy'] = {}

        restart_policy_name = restart_policy.name
        restart_policy_name = 'on-failure' unless ["always", "on-failure", "no"].include?(restart_policy_name)

        host_config['RestartPolicy']['Name'] = restart_policy_name
        host_config['RestartPolicy']['MaximumRetryCount'] = restart_policy.max_retry_count || 10 if restart_policy_name == 'on-failure'
      end

      host_config
    end

    def build_console_config(server_name, &block)
      build_config(server_name, &block).merge({
        'Cmd' => ['/bin/bash'],
        'AttachStdin' => true,
        'Tty'         => true,
        'OpenStdin'   => true,
      })
    end

    def volume_binds_config
      @volumes.map { |volume| "#{volume.host_volume}:#{volume.container_volume}" }
    end

    def port_bindings_config
      @port_bindings.inject({}) do |memo, binding|
        config = {}
        config['HostPort'] = binding.host_port.to_s
        config['HostIp'] = binding.host_ip if binding.host_ip
        memo["#{binding.container_port}/#{binding.type}"] = [config]
        memo
      end
    end

    def public_ports
      @port_bindings.map(&:host_port)
    end

    private

    def is_a_uint64?(value)
      result = false
      if !value.is_a? Integer
        return result
      end
      if value < 0 || value > 0xFFFFFFFFFFFFFFFF
        return result
      end
      return true
    end

    def interpolate_var(val, hostname)
      val.to_s.gsub('%DOCKER_HOSTNAME%', hostname)
        .gsub('%DOCKER_HOST_IP%', host_ip(hostname))
    end

    def host_ip(hostname)
      @host_ip ||= {}
      return @host_ip[hostname] if @host_ip.has_key?(hostname)
      @host_ip[hostname] = Socket.getaddrinfo(hostname, nil).first[2]
    end

    class RestartPolicy < Struct.new(:name, :max_retry_count)
    end

    class Volume < Struct.new(:host_volume, :container_volume)
    end

    class PortBinding < Struct.new(:host_port, :container_port, :type, :host_ip)
    end
  end
end
