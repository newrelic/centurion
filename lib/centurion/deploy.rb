require 'excon'
require 'uri'

module Centurion; end

module Centurion::Deploy
  FAILED_CONTAINER_VALIDATION = 100

  def stop_containers(target_server, port_bindings)
    public_port    = public_port_for(port_bindings)
    old_containers = target_server.find_containers_by_public_port(public_port)
    info "Stopping container(s): #{old_containers.inspect}"

    old_containers.each do |old_container|
      info "Stopping old container #{old_container['Id'][0..7]} (#{old_container['Names'].join(',')})"
      target_server.stop_container(old_container['Id'])
    end
  end

  def wait_for_http_status_ok(url, image_id, tag, sleep_time=5, retries=12, secondary_url=nil)
    uri = URI.parse(url)
    secondary_check = define_secondary_check(secondary_url)

    info 'Waiting for the port to come up'
    1.upto(retries) do
      if container_up?(uri.host, uri.port) && http_status_ok?(url) && secondary_check.call
        info 'Container is up!'
        break
      end

      info "Waiting #{sleep_time} seconds to test the #{uri.path} endpoint..."
      sleep(sleep_time)
    end

    unless http_status_ok?(url) && secondary_check.call
      error "Failed to validate started container on #{uri.host}:#{uri.port}"
      exit(FAILED_CONTAINER_VALIDATION)
    end
  end

  def container_up?(target_server, port)
    # The API returns a record set like this:
    #[{"Command"=>"script/run ", "Created"=>1394470428, "Id"=>"41a68bda6eb0a5bb78bbde19363e543f9c4f0e845a3eb130a6253972051bffb0", "Image"=>"quay.io/newrelic/rubicon:5f23ac3fad7979cd1efdc9295e0d8c5707d1c806", "Names"=>["/happy_pike"], "Ports"=>[{"IP"=>"0.0.0.0", "PrivatePort"=>80, "PublicPort"=>8484, "Type"=>"tcp"}], "Status"=>"Up 13 seconds"}]

    running_containers = target_server.find_containers_by_public_port(port)
    container = running_containers.pop

    unless running_containers.empty?
      # This _should_ never happen, but...
      error "More than one container is bound to port #{port} on #{target_server}!"
      return false
    end

    if container && container['Ports'].any? { |bind| bind['PublicPort'].to_i == port.to_i }
      info "Found container up for #{Time.now.to_i - container['Created'].to_i} seconds"
      return true
    end

    false
  end

  def http_status_ok?(url)
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

  def cleanup_containers(target_server, port_bindings)
    public_port    = public_port_for(port_bindings)
    old_containers = target_server.old_containers_for_port(public_port)
    old_containers.shift(2)

    info "Public port #{public_port}"
    old_containers.each do |old_container|
      info "Removing old container #{old_container['Id'][0..7]} (#{old_container['Names'].join(',')})"
      target_server.remove_container(old_container['Id'])
    end
  end

  def container_config_for(target_server, image_id, port_bindings=nil, env_vars=nil, volumes=nil)
    container_config = {
      'Image'        => image_id,
      'Hostname'     => target_server.hostname,
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

  def start_new_container(target_server, image_id, port_bindings, volumes, env_vars=nil)
    container_config = container_config_for(target_server, image_id, port_bindings, env_vars, volumes)
    start_container_with_config(target_server, volumes, port_bindings, container_config)
  end

  def launch_console(target_server, image_id, port_bindings, volumes, env_vars=nil)
    container_config = container_config_for(target_server, image_id, port_bindings, env_vars, volumes).merge(
      'Cmd'         => [ '/bin/bash' ],
      'AttachStdin' => true,
      'Tty'         => true,
      'OpenStdin'   => true,
    )

    container = start_container_with_config(target_server, volumes, port_bindings, container_config)

    target_server.attach(container['Id'])
  end

  private
  
  def start_container_with_config(target_server, volumes, port_bindings, container_config)
    info "Creating new container for #{container_config['Image'][0..7]}"
    new_container = target_server.create_container(container_config)

    host_config = {}
    # Map some host volumes if needed
    host_config['Binds'] = volumes if volumes && !volumes.empty?
    # Bind the ports
    host_config['PortBindings'] = port_bindings 

    info "Starting new container #{new_container['Id'][0..7]}"
    target_server.start_container(new_container['Id'], host_config)

    info "Inspecting new container #{new_container['Id'][0..7]}:"
    info target_server.inspect_container(new_container['Id'])

    new_container
  end

  def define_secondary_check(secondary_url)
    return lambda { true } if secondary_url.nil?
    lambda { http_status_ok?(secondary_url) }
  end
end
