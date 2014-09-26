module Centurion; end

class Centurion::Dogestry
  def initialize(options = {})
    @options = options
  end

  def aws_access_key
    @options[:aws_access_key]
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

  def exec_command(command, repo)
    "dogestry #{command} #{s3_url} #{repo}"
  end

  def pull(repo)
    `#{exec_command('pull', repo)}`
  end

  def push(repo)
    `#{exec_command('push', repo)}`
  end
end
