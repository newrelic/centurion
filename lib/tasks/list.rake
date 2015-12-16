require 'centurion/docker_registry'

task :list do
  invoke 'list:tags'
  invoke 'list:running_containers'
end

namespace :list do
  task :running_container_tags do

    tags = get_current_tags_for(fetch(:image))

    $stderr.puts "\n\nCurrent #{current_environment} tags for #{fetch(:image)}:\n\n"
    tags.each do |info|
      if info && !info[:tags].empty?
        $stderr.puts "#{'%-20s' % info[:server]}: #{info[:tags].join(', ')}"
      else
        $stderr.puts "#{'%-20s' % info[:server]}: NO TAGS!"
      end
    end

    $stderr.puts "\nAll tags for this image: #{tags.map { |t| t[:tags] }.flatten.uniq.join(', ')}"
  end

  task :tags do
    begin
      registry = Centurion::DockerRegistry.new(
        fetch(:docker_registry),
        fetch(:registry_user),
        fetch(:registry_password),
        fetch(:registry_version)
      )
      tags = registry.repository_tags(fetch(:image))
      tags.each do |tag|
        if tag.length > 1
          puts "\t#{tag[0]}\t-> #{tag[1][0..11]}"
        else
          puts "\t#{tag[0]}"
        end
      end
    rescue StandardError => e
      error "Couldn't communicate with Registry: #{e.message}"
    end
    puts
  end

  task :running_containers do
    on_each_docker_host do |target_server|
      begin
        running_containers = target_server.ps
        running_containers.each do |container|
          puts container.inspect
        end
      rescue StandardError => e
        error "Couldn't communicate with Docker on #{target_server.hostname}: #{e.message}"
        raise
      end
      puts
    end
  end
end
