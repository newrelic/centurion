module Centurion
  # Callbacks to allow hooking into the deploy lifecycle. This could
  # be useful to communicate with a loadbalancer, chat room, etc.
  module DeployCallbacks
    def stop_containers(target_server, service, timeout = 30)
      before_stopping_container_callbacks.each do |callback|
        callback.call target_server
      end
      super target_server, service, timeout
    end

    private

    def before_stopping_container_callbacks
      fetch :before_stopping_container_callbacks, []
    end
  end
end
