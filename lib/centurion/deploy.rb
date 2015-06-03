require 'excon'
require 'socket'

module Centurion; end

module Centurion::Deploy
  FAILED_CONTAINER_VALIDATION = 100

  def stop_containers(target_server, service, timeout = 30)
    old_containers = target_server.find_containers_by_public_port(service.public_ports.first)
    info "Stopping container(s): #{old_containers.inspect}"

    old_containers.each do |old_container|
      info "Stopping old container #{old_container['Id'][0..7]} (#{old_container['Names'].join(',')})"
      target_server.stop_container(old_container['Id'], timeout)
    end
  end

  def wait_for_health_check_ok(health_check_method, target_server, port, endpoint, image_id, tag, sleep_time=5, retries=12)
    info 'Waiting for the port to come up'
    1.upto(retries) do
      if container_up?(target_server, port) && health_check_method.call(target_server, port, endpoint)
        info 'Container is up!'
        break
      end

      info "Waiting #{sleep_time} seconds to test the #{endpoint} endpoint..."
      sleep(sleep_time)
    end

    unless health_check_method.call(target_server, port, endpoint)
      error "Failed to validate started container on #{target_server}:#{port}"
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

  def http_status_ok?(target_server, port, endpoint)
    url      = "http://#{target_server.hostname}:#{port}#{endpoint}"
    response = begin
      Excon.get(url, :headers => {'Accept' => '*/*'})
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

  def cleanup_containers(target_server, service)
    public_port = service.public_ports.first
    old_containers = target_server.old_containers_for_port(public_port)
    old_containers.shift(2)

    info "Public port #{public_port}"
    old_containers.each do |old_container|
      info "Removing old container #{old_container['Id'][0..7]} (#{old_container['Names'].join(',')})"
      target_server.remove_container(old_container['Id'])
    end
  end

  def hostname_proc
    hostname = fetch(:container_hostname)
    if hostname.respond_to?(:call)
      hostname
    else
      ->(s){ s }
    end
  end

  def start_new_container(server, service, restart_policy)
    container_config = service.build_config(server.hostname, &hostname_proc)
    info "Creating new container for #{container_config['Image'][0..7]}"
    container = server.create_container(container_config, service.name)

    host_config = service.build_host_config(restart_policy)

    info "Starting new container #{container['Id'][0..7]}"
    server.start_container(container['Id'], host_config)

    info "Inspecting new container #{container['Id'][0..7]}:"
    info server.inspect_container(container['Id'])

    container
  end

  def launch_console(server, service)
    container_config = service.build_console_config(server.hostname)
    info "Creating new container for #{container_config['Image'][0..7]}"

    container = server.create_container(container_config, service.name)

    host_config = service.build_host_config

    info "Starting new container #{container['Id'][0..7]}"
    server.start_container(container['Id'], host_config)

    server.attach(container['Id'])
  end
end
