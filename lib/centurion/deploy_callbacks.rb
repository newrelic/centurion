module Centurion
  # Callbacks to allow hooking into the deploy lifecycle. This could
  # be useful to communicate with a loadbalancer, chat room, etc.
  module DeployCallbacks
    def stop_containers(server, service, timeout = 30)
      emit :before_stopping_image, server
      super server, service, timeout
    end

    def start_new_container(server, service, restart_policy)
      super(server, service, restart_policy).tap { emit :after_image_started, server }
    end

    def wait_for_health_check_ok(health_check_method, server, port, endpoint, image_id, tag, sleep_time=5, retries=12)
      super(health_check_method,
            server,
            port,
            endpoint,
            image_id,
            tag,
            sleep_time,
            retries).tap { emit :after_health_check_ok, server }
    end

    private

    def emit(name, *args)
      callbacks[name].each do |callback|
        callback.call(*args)
      end
    end

    def callbacks
      fetch 'callbacks', Hash.new { [] }
    end
  end
end
