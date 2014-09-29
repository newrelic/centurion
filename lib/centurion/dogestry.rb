require_relative 'logging'

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
  end

  def exec_command(command, repo)
    "dogestry #{command} #{s3_url} #{repo}"
  end

  def pull(repo)
    validate_before_exec
    set_envs

    output = `#{exec_command('pull', repo)}`
    exit_status = $?.to_i

    if exit_status == 0
      info output
      return output
    else
      error output
      raise output
    end
  end

  def push(repo)
    validate_before_exec
    set_envs

    output = `#{exec_command('push', repo)}`
    exit_status = $?.to_i

    if exit_status == 0
      info output
      return output
    else
      error output
      raise output
    end
  end
end
