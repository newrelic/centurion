module Centurion
  # Callbacks to allow hooking into the deploy lifecycle. This could
  # be useful to communicate with a loadbalancer, chat room, etc.
  module DeployCallbacks
    def stop_containers(server, service, timeout = 30)
      before_stopping_container_callbacks.each do |callback|
        callback.call server
      end
      super server, service, timeout
    end

    def start_new_container(server, service, restart_policy)
      result = super server, service, restart_policy
      after_new_container_started_callbacks.each do |callback|
        callback.call server
      end
      result
    end

    private

    def before_stopping_container_callbacks
      fetch :before_stopping_image_callbacks, []
    end

    def after_new_container_started_callbacks
      fetch :after_image_started_callbacks, []
    end
  end
end
