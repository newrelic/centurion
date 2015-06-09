require_relative 'logging'
require_relative 'shell'
require 'fileutils'

module Centurion; end

class Centurion::Dogestry
  include Centurion::Logging
  attr_accessor :options

  def initialize(options = {})
    @options = options
  end

  # Cross-platform way of finding an executable in the $PATH.
  #   which('ruby') #=> /usr/bin/ruby
  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable?(exe) && !File.directory?(exe)
      end
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

  def set_envs()
    ENV['AWS_ACCESS_KEY'] = aws_access_key_id
    ENV['AWS_SECRET_KEY'] = aws_secret_key

    info "Dogestry ENV: #{ENV.inspect}"
  end

  def exec_command(command, repo, flags="")
    command = "dogestry #{flags} #{command} #{s3_url} #{repo}"
    info "Executing: #{command}"
    command
  end

  def pull(repo, pull_hosts)
    validate_before_exec
    set_envs()

    hosts = pull_hosts.join(",")
    flags = "-pullhosts #{hosts}"

    Centurion::Shell.echo(exec_command('pull', repo, flags))
  end
end
