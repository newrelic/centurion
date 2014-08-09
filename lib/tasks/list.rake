require 'centurion/docker_registry'
require 'centurion/api'

task :list do
  invoke 'list:tags'
  invoke 'list:running_containers'
end

namespace :list do
  task :running_container_tags do
    output = []
    on_each_docker_host do |host|
      tags = []
      Docker::Container.all({}, host).each do |container|
        image = Centurion::Api.get_image_by_container(host, container)
        tags << Centurion::Api.get_all_tags_for_image(host, image) if Centurion::Api.tag_matches_image_name?(fetch(:image), image.info["RepoTags"])
      end
      output << {server: URI.parse(host.url).host, tags: tags} if tags
    end


    $stderr.puts "\n\nCurrent #{current_environment} tags for image - #{fetch(:image)}:\n\n"
    output.each do |info|
      if info && !info[:tags].empty?
        $stderr.puts "#{'%-20s' % info[:server]}: #{info[:tags].join(', ')}"
      else
        $stderr.puts "#{'%-20s' % info[:server]}: NO TAGS!"
      end
    end

    $stderr.puts "\nAll tags for this image: #{output.map { |t| t[:tags] }.flatten.uniq.join(', ')}"
  end

  task :tags do
    begin
      registry = Centurion::DockerRegistry.new(fetch(:docker_registry))
      tags = registry.repository_tags(fetch(:image))
      tags.each do |tag|
        puts "\t#{tag[0]}\t-> #{tag[1][0..11]}"
      end
    rescue StandardError => e
      error "Couldn't communicate with Registry: #{e.message}"
    end
    puts
  end

  task :running_containers do
    on_each_docker_host do |host|
      Docker::Container.all({}, host).each do |running_container|
        puts "#{host.url} : #{running_container.info['Image']} -- #{running_container.json['Name']} (#{running_container.json['Id'][0..7]})"
      end
    end
  end
end
