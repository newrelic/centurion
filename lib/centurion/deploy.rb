require_relative 'api'
require 'excon'

module Centurion; end

module Centurion::Deploy
  FAILED_CONTAINER_VALIDATION = 100

  def stop_containers(host, port_bindings)
    public_port = public_port_for(port_bindings)

    Centurion::Api.get_containers_by_port(host, public_port).each do |container|
      info "Stopping old container #{container.id[0..7]} (#{container.info["Name"]})"
      container.kill
    end
  end

  def wait_for_http_status_ok(host, port, endpoint, image_id, tag, sleep_time=5, retries=12)
    info 'Waiting for the port to come up'
    1.upto(retries) do
      if container_up?(host, port) && http_status_ok?(host, port, endpoint)
        info 'Container is up!'
        break
      end

      info "Waiting #{sleep_time} seconds to test the #{URI.parse(host.url).host}:#{port}#{endpoint} endpoint..."
      sleep(sleep_time)
    end

    unless http_status_ok?(host, port, endpoint)
      error "Failed to validate started container on #{host}:#{port}"
      exit(FAILED_CONTAINER_VALIDATION)
    end
  end

  def container_up?(host, public_port)
    # The API returns a record set like this:
    #[{"Command"=>"script/run ", "Created"=>1394470428, "Id"=>"41a68bda6eb0a5bb78bbde19363e543f9c4f0e845a3eb130a6253972051bffb0", "Image"=>"quay.io/newrelic/rubicon:5f23ac3fad7979cd1efdc9295e0d8c5707d1c806", "Names"=>["/happy_pike"], "Ports"=>[{"IP"=>"0.0.0.0", "PrivatePort"=>80, "PublicPort"=>8484, "Type"=>"tcp"}], "Status"=>"Up 13 seconds"}]

    running_containers = Centurion::Api.get_containers_by_port(host, public_port)
    container = running_containers.pop

    unless running_containers.empty?
      # This _should_ never happen, but...
      error "More than one container is bound to port #{public_port} on #{host}!"
      return false
    end

    if container
      time = Time.now - Time.parse(container.json["State"]["StartedAt"])
      info "Found container up for #{time.round(2)} seconds"
      return true
    end

    false
  end

  def http_status_ok?(host, port, endpoint)
    url = "http://#{URI.parse(host.url).host}:#{port}#{endpoint}"
    response = begin
      Excon.get(url)
    rescue Excon::Errors::SocketError
      warn "Failed to connect to #{url}, no socket open."
      nil
    end

    return false unless response
    return true if response.status >= 200 && response.status < 300

    warn "Got HTTP status: #{response.status}" 
    false
  end

  def wait_for_load_balancer_check_interval
    sleep(fetch(:rolling_deploy_check_interval, 5))
  end

  def cleanup_containers(host, public_port)
    old_containers = Centurion::Api.get_non_running_containers(host)
    old_containers.each do |container| 
      info "Removing the following container - #{container.id[0..11]}"
      container.remove
    end
  end

  def container_config_for(host, image_id, port_bindings=nil, env_vars=nil, volumes=nil)
    container_config = {
      'Image'        => image_id,
      'Hostname'     => URI.parse(host.url).host,
    }

    if port_bindings
      container_config['ExposedPorts'] ||= {}
      port_bindings.keys.each do |port|
        container_config['ExposedPorts'][port] = {}
      end
    end

    if env_vars
      container_config['Env'] = env_vars.map do |k,v|
        "#{k}=#{v.gsub('%DOCKER_HOSTNAME%', target_server.hostname)}"
      end
    end

    if volumes
      container_config['Volumes'] = volumes.inject({}) do |memo, v|
        memo[v.split(/:/).last] = {}
        memo
      end
      container_config['VolumesFrom'] = 'parent'
    end

    container_config
  end

  def start_new_container(host, image_id, port_bindings, volumes, env_vars=nil)
    container_config = container_config_for(host, image_id, port_bindings, env_vars, volumes)
    start_container_with_config(host, volumes, port_bindings, container_config)
  end

  def launch_console(host, image_id, port_bindings, volumes, env_vars=nil)
    container_config = container_config_for(host, image_id, port_bindings, env_vars, volumes).merge(
      'Cmd'          => ['/bin/bash'],
      'AttachStdin'  => true,
      'Tty'          => true,
      'OpenStdin'    => true)

    container = start_container_with_config(host, volumes, port_bindings, container_config)
    # container.attach({:stream => true, :stdin => true, :stdout => true, :stderr => true, :tty => true})
  end

  private
  
  def start_container_with_config(host, volumes, port_bindings, container_config)
    info "Creating new container for image (#{container_config['Image'][0..7]})"
    container = Docker::Container.create(container_config, host)

    host_config = {}
    # Map some host volumes if needed
    host_config['Binds'] = volumes if volumes && !volumes.empty?
    # Bind the ports
    host_config['PortBindings'] = port_bindings 

    info "Starting new container #{container.id[0..11]}"
    container = container.start!(host_config)
    
    info "Inspecting new container #{container.id[0..11]}:"
    info container.top.inspect

    container
  end
end
