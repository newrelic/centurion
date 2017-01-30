namespace :environment do
  task :common do
    set :image, 'redis'
    host '10.11.11.111:4243'
    host_port 6379, container_port: 6379
  end

  desc 'Staging environment'
  task staging: :common do
    set_current_environment(:staging)
  end

  task rename_container: :common do
    set :name, 'new-container-name'
  end
end
