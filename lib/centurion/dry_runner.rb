module Centurion
  class DryRunner
    def initialize(env)
      environment = env[:current_environment]
      @options = env[environment]
    end

    def run
      puts result
    end

    private

    attr_reader :options

    # Metaprogramming to define the following for mutliple objects:
    #
    #   def ports
    #     [*options[:port_bindings]]
    #   end
    %i(env_vars port_bindings hosts).each do |key|
      define_method key do
        [*options[key]]
      end
    end

    def result
      hosts.map do |host|
        string = "docker -H=tcp://#{host}:2375 run"

        string << environment_vars unless env_vars.empty?
        string << ports_vars unless ports_vars.empty?
        string
      end.join("\n\n\n ******* \n\n\n")
    end

    def environment_vars
      env_vars.reduce('') do |string, (k, v)|
        " -e #{k.split('"')[0]}='#{v.gsub(/\n/, '')}'#{string}"
      end.rstrip
    end

    def ports_vars
      port_bindings.reduce('') do |string, port_binding|
        protocol = port_binding.type
        host_port = port_binding.host_port
        container_port = port_binding.container_port
        " -p #{host_port}:#{container_port}/#{protocol}#{string}"
      end.rstrip
    end
  end
end
