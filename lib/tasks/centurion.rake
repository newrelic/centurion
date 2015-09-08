# The centurion:setup task is always run first to do any prework needed
# to ensure a consistent and functioning environment

namespace :centurion do
  task :setup => [:clean_environment]

  task :clean_environment do
    ENV.delete('DOCKER_HOST')
    ENV.delete('DOCKER_TLS_VERIFY')
    set(:original_docker_cert_path, ENV['DOCKER_CERT_PATH'])
    ENV.delete('DOCKER_CERT_PATH')
  end
end
