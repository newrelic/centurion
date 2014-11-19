require_relative 'logging'
require 'fileutils'

module Centurion; end

class Centurion::Dogestry
  include Centurion::Logging

  def initialize(options = {})
    @options = options
  end

  # Cross-platform way of finding an executable in the $PATH.
  #   which('ruby') #=> /usr/bin/ruby
  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable?(exe) && !File.directory?(exe)
      }
    end
    return nil
  end

  def validate_before_exec
    unless which('dogestry')
      message = 'Unable to find "dogestry" executable'
      error message
      raise message
    end
  end

  def aws_access_key_id
    @options[:aws_access_key_id]
  end

  def aws_secret_key
    @options[:aws_secret_key]
  end

  def s3_bucket
    @options[:s3_bucket]
  end

  def s3_region
    @options[:s3_region] || 'us-east-1'
  end

  def s3_url
    "s3://#{s3_bucket}/?region=#{s3_region}"
  end

  def docker_host
    @options[:docker_host] || 'tcp://localhost:2375'
  end

  def set_envs
    ENV['DOCKER_HOST'] = docker_host
    ENV['AWS_ACCESS_KEY'] = aws_access_key_id
    ENV['AWS_SECRET_KEY'] = aws_secret_key

    info "Dogestry ENV: #{ENV.inspect}"
  end

  def exec_command(command, repo, flags="")
    command = "dogestry #{command} #{flags} #{s3_url} #{repo}"
    info "Executing: #{command}"
    command
  end

  def pull(repo)
    validate_before_exec
    set_envs

    echo(exec_command('pull', repo))
  end

  def push(repo)
    validate_before_exec
    set_envs

    echo(exec_command('push', repo))
  end

  def download_image_to_temp_dir(repo, local_dir)
    validate_before_exec
    set_envs

    flags = "-tempdir #{File.expand_path(local_dir)}"

    echo(exec_command('download', repo, flags=flags))
  end

  def upload_temp_dir_image_to_docker(repo, local_dir)
    validate_before_exec
    set_envs

    repo_and_local_dir = "#{local_dir} #{repo}"

    echo(exec_command('upload', repo_and_local_dir))
  end

  def create_tmp_dir(length)
    tmp_dir = "/tmp/#{rand(36**length).to_s(36)}"
    FileUtils::mkdir_p(tmp_dir)
    tmp_dir
  end
end
