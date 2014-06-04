task :info => 'info:default'

namespace :info do
  task :default do
    puts "Environment: #{fetch(:environment)}"
    puts "Project: #{fetch(:project)}"
    puts "Image: #{fetch(:image)}"
    puts "Tag: #{fetch(:tag)}"
    puts "Port Bindings: #{fetch(:port_bindings).inspect}"
    puts "Mount Point: #{fetch(:binds).inspect}"
    puts "ENV: #{fetch(:env_vars).inspect}"
    puts "Hosts: #{fetch(:hosts).inspect}"
  end

  task :run_command do
    example_host = fetch(:hosts).first
    env_args = ""
    fetch(:env_vars, {}).each_pair do |name,value|
      env_args << "-e #{name}='#{value}' "
    end
    volume_args = fetch(:binds, []).map {|bind| "-v #{bind}"}.join(" ")
    puts "docker -H=tcp://#{example_host} run #{env_args} #{volume_args} #{fetch(:image)}:#{fetch(:tag)}"
  end
end
