module Centurion
  class Mock
    def initialize(opts)
      environment = opts[:current_environment]
      @options = opts[environment]
    end

    def run
      require 'pry-byebug'

      result = hosts.map do |host|
        string = "docker -H=tcp://#{host}:2375 run"

        string << environment_vars unless env_vars.empty?
        string << ports_vars unless ports_vars.empty?
      end.join("\n\n\n ******* \n\n\n")
      puts "#{result}"
    end

    private

    attr_reader :options


    def env_vars
      options[:env_vars]
    end

    def environment_vars
      env_vars.reduce('') { |string, (k, v)| " -e #{k.split('"')[0]}='#{v}'#{string}" }.rstrip
    end

    def ports
      options[:port_bindings]
    end

    def hosts
      options[:hosts]
    end

    def ports_vars
      ports.reduce('') do |string, (host_port_protocol, container_port)|
        h = host_port_protocol.split('/')
        c = container_port.first['HostPort']
        " -p #{h[0]}:#{c}/#{h[1]}#{string}"
      end.rstrip
    end
  end
end
