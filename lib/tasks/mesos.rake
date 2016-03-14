require 'thread'
require 'excon'
require 'centurion/deploy'
require 'tmpdir'
require 'json'

namespace :mesos do
  include Centurion::MesosActions

  task :deploy do    
    create_new defined_mesos_service
  end      

  task :list do
    list defined_mesos_service
  end

  task :deploy_console do
    defined_service.instances = 1
    defined_service.env_vars[:SERVICE_NAME] += "-console"
    launch_console defined_mesos_service
  end

  task :rolling_upgrade do
    rolling_upgrade defined_mesos_service
  end

  task :delete do
    delete_app defined_mesos_service
  end                

end