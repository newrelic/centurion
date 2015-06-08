module Centurion
  # Callbacks to allow hooking into the deploy lifecycle. This could
  # be useful to communicate with a loadbalancer, chat room, etc.
  module DeployCallbacks
    def stop_containers(server, service, timeout = 30)
      callbacks(:before_stopping_image).each do |callback|
        callback.call server
      end
      super server, service, timeout
    end

    def start_new_container(server, service, restart_policy)
      result = super server, service, restart_policy
      callbacks(:after_image_started).each do |callback|
        callback.call server
      end
      result
    end

    def wait_for_health_check_ok(health_check_method, server, port, endpoint, image_id, tag, sleep_time=5, retries=12)
      result = super health_check_method,
                     server,
                     port,
                     endpoint,
                     image_id,
                     tag,
                     sleep_time,
                     retries

      callbacks(:after_health_check_ok).each do |callback|
        callback.call server
      end
      result
    end

    private

    def callbacks(name)
      fetch "#{name}_callbacks".to_sym, []
    end
  end
end
