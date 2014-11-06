require 'thread'
require 'excon'
require 'centurion/deploy'

task :deploy do
  invoke 'deploy:get_image'
  invoke 'deploy:stop'
  invoke 'deploy:start_new'
  invoke 'deploy:cleanup'
end

task :deploy_console do
  invoke 'deploy:get_image'
  invoke 'deploy:stop'
  invoke 'deploy:launch_console'
  invoke 'deploy:cleanup'
end

task :rolling_deploy do
  invoke 'deploy:get_image'
  invoke 'deploy:rolling_deploy'
  invoke 'deploy:cleanup'
end

task :stop => ['deploy:stop']

namespace :deploy do
  include Centurion::Deploy

  namespace :dogestry do
    task :validate_pull_image do
      ['aws_access_key_id', 'aws_secret_key', 's3_bucket'].each do |env_var|
        unless fetch(env_var.to_sym)
          $stderr.puts "\n\n#{env_var} is not defined."
          exit(1)
        end
      end
    end

    task :pull_image do
      invoke 'deploy:dogestry:validate_pull_image'

      target_servers = Centurion::DockerServerGroup.new(fetch(:hosts), fetch(:docker_path))
      target_servers.each_in_parallel do |target_server|
        dogestry_options = {
          aws_access_key_id: fetch(:aws_access_key_id),
          aws_secret_key: fetch(:aws_secret_key),
          s3_bucket: fetch(:s3_bucket),
          s3_region: fetch(:s3_region) || 'us-east-1',
          docker_host: "tcp://#{target_server.hostname}:#{target_server.port}"
        }

        $stdout.puts "** Pulling image(#{fetch(:image)}:#{fetch(:tag)}) from Dogestry: #{dogestry_options.inspect}"

        registry = Centurion::Dogestry.new(dogestry_options)

        registry.pull("#{fetch(:image)}:#{fetch(:tag)}")
      end
    end
  end

  task :get_image do
    invoke 'deploy:pull_image'
    invoke 'deploy:determine_image_id_from_first_server'
    invoke 'deploy:verify_image'
  end

  # stop
  # - remote: list
  # - remote: stop
  task :stop do
    on_each_docker_host do |server|
      stop_containers(server, fetch(:port_bindings), fetch(:stop_timeout, 30))
    end
  end

  # start
  # - remote: create
  # - remote: start
  # - remote: inspect container
  task :start_new do
    on_each_docker_host do |server|
      start_new_container(
        server,
        fetch(:image_id),
        fetch(:port_bindings),
        fetch(:binds),
        fetch(:env_vars),
        fetch(:command)
      )
    end
  end

  task :launch_console do
    on_each_docker_host do |server|
      launch_console(
        server,
        fetch(:image_id),
        fetch(:port_bindings),
        fetch(:binds),
        fetch(:env_vars)
      )
    end
  end

  task :rolling_deploy do
    on_each_docker_host do |server|
      stop_containers(server, fetch(:port_bindings), fetch(:stop_timeout, 30))

      start_new_container(
        server,
        fetch(:image_id),
        fetch(:port_bindings),
        fetch(:binds),
        fetch(:env_vars)
      )

      fetch(:port_bindings).each_pair do |container_port, host_ports|
        wait_for_http_status_ok(
          server,
          host_ports.first['HostPort'],
          fetch(:status_endpoint, '/'),
          fetch(:image),
          fetch(:tag),
          fetch(:rolling_deploy_wait_time, 5),
          fetch(:rolling_deploy_retries, 24)
        )
      end

      wait_for_load_balancer_check_interval
    end
  end

  task :cleanup do
    on_each_docker_host do |target_server|
      cleanup_containers(target_server, fetch(:port_bindings))
    end
  end

  task :determine_image_id do
    registry = Centurion::DockerRegistry.new(fetch(:docker_registry))
    exact_image = registry.digest_for_tag(fetch(:image), fetch(:tag))
    set :image_id, exact_image
    $stderr.puts "RESOLVED #{fetch(:image)}:#{fetch(:tag)} => #{exact_image[0..11]}"
  end

  task :determine_image_id_from_first_server do
    on_each_docker_host do |target_server|
      image_detail = target_server.inspect_image(fetch(:image), fetch(:tag))
      exact_image = image_detail["id"]
      set :image_id, exact_image
      $stderr.puts "RESOLVED #{fetch(:image)}:#{fetch(:tag)} => #{exact_image[0..11]}"
      break
    end
  end

  task :pull_image do
    if fetch(:no_pull)
      info "--no-pull option specified: skipping pull"
      next
    end

    $stderr.puts "Fetching image #{fetch(:image)}:#{fetch(:tag)} IN PARALLEL\n"

    if fetch(:registry) == 'dogestry'
      invoke 'deploy:dogestry:pull_image'
    else
      target_servers = Centurion::DockerServerGroup.new(fetch(:hosts), fetch(:docker_path))
      target_servers.each_in_parallel do |target_server|
        target_server.pull(fetch(:image), fetch(:tag))
      end
    end
  end

  task :verify_image do
    on_each_docker_host do |target_server|
      image_detail = target_server.inspect_image(fetch(:image), fetch(:tag))
      found_image_id = image_detail["id"]

      if found_image_id == fetch(:image_id)
        $stderr.puts "Image #{found_image_id[0..7]} found on #{target_server.hostname}"
      else
        raise "Did not find image #{fetch(:image_id)} on host #{target_server.hostname}!"
      end

      # Print the container config
      image_detail["container_config"].each_pair do |key,value|
        $stderr.puts "\t#{key} => #{value.inspect}"
      end
    end
  end

  task :promote_from_staging do
    if fetch(:environment) == 'staging'
      $stderr.puts "\n\nYour target environment needs to not be 'staging' to promote from staging."
      exit(1)
    end

    starting_environment = current_environment

    # Set our env to staging so we can grab the current tag.
    invoke 'environment:staging'

    staging_tags = get_current_tags_for(fetch(:image)).map { |t| t[:tags] }.flatten.uniq

    if staging_tags.size != 1
      $stderr.puts "\n\nUh, oh: Not sure which staging tag to deploy! Found:(#{staging_tags.join(', ')})"
      exit(1)
    end

    $stderr.puts "Staging environment has #{staging_tags.first} deployed."

    # Make sure that we set our env back to production, then update the tag.
    set_current_environment(starting_environment)
    set :tag, staging_tags.first

    $stderr.puts "Deploying #{fetch(:tag)} to the #{starting_environment} environment"

    invoke 'deploy'
  end
end
