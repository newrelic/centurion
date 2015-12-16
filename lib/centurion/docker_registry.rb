require 'excon'
require 'json'
require 'uri'
require 'base64'

module Centurion; end

class Centurion::DockerRegistry
  OFFICIAL_URL = 'https://registry.hub.docker.com'
  OFFICIAL_AUTH_URL = 'https://auth.docker.io/token'

  def initialize(base_uri, registry_user=nil, registry_password=nil, registry_version=nil)
    @base_uri = base_uri
    @user = registry_user
    @password = registry_password
    registry_version ||= '1'
    @registry_version = registry_version
  end

  def digest_for_tag(repository, tag)
    if @registry_version == '2'
      digest_for_tag_v2(repository, path)
    end

    path = "/v#{@registry_version}/repositories/#{repository}/tags/#{tag}"

    uri = uri_for_repository_path(repository, path)
    $stderr.puts "GET: #{uri}"
    options = { headers: { "Content-Type" => "application/json" } }
    if @user
      options[:user] = @user
      options[:password] = @password
    end
    response = Excon.get(
      uri,
      options
    )
    raise response.inspect unless response.status == 200

    # This hack is stupid, and I hate it. But it works around the fact that
    # the Docker Registry will return a base JSON String, which the Ruby parser
    # refuses (possibly correctly) to handle
    JSON.load('[' + response.body + ']').first
  end

  def repository_tags(repository)
    if @registry_version == '2'
      digest_for_tag_v2(repository, path)
    end

    path = "/v#{@registry_version}/repositories/#{repository}/tags"

    uri = uri_for_repository_path(repository, path)

    $stderr.puts "GET: #{uri.inspect}"

    # Need to workaround a bug in Docker Hub to now pass port in Host header
    options = { omit_default_port: true }

    if @user
      options[:user] = @user
      options[:password] = @password
    end

    response = Excon.get(uri, options)
    raise response.inspect unless response.status == 200

    tags = JSON.load(response.body)

    # The Docker Registry API[1]  specifies a result in the format
    # { "[tag]" : "[image_id]" }. However, the official Docker registry returns a
    # result like [{ "layer": "[image_id]", "name": "[tag]" }].
    #
    # So, we need to normalize the response to what the Docker Registry API
    # specifies should be returned.
    #
    # [1]: https://docs.docker.com/v1.1/reference/api/registry_api/

    if is_official_registry?(repository)
      tags.each_with_object({}) do |tag, hash|
        hash[tag['name']] = tag['layer']
      end
    else
      tags
    end
  end

  private

  def v2_login(authentication)
    auth_arr = authentication.split(' ')[1].split(',')
    auth_hash = {}

    auth_arr.each do |e|
      key_value = e.split('=')
      auth_hash[key_value[0]] = key_value[1].gsub!(/\A"|"\Z/, '')
    end

    path = "/?service=#{auth_hash['service']}&scope=#{auth_hash['scope']}"
    uri = "#{auth_hash['realm'].gsub('token', 'v' + @registry_version) + '/token'}#{path}"

    $stderr.puts "GET: #{uri.inspect}"

    options = {
      omit_default_port: true,
      headers: { "Authorization" => "Basic #{Base64.strict_encode64(@user + ':' + @password)}" }
    }

    $stderr.puts "HEADERS: #{options.inspect}"

    response = Excon.get(uri, options)

    raise response.inspect unless response.status == 200

    body = JSON.load(response.body)
    raise "No token returned!" if body['token'].nil?

    return body['token']
  end

  def digest_for_tag_v2(repository, tag)

  end

  def repository_tags_v2(repository, token = nil)
    path = "/v#{@registry_version}/#{repository}/tags/list"
    uri = uri_for_repository_path(repository, path)

    $stderr.puts "GET: #{uri.inspect}"

    # Need to workaround a bug in Docker Hub to now pass port in Host header
    options = { omit_default_port: true }

    unless token.nil?
      options[:headers] = {
        "Authorization" => "Bearer #{token}"
      }
    end

    response = Excon.get(uri, options)

    if response.status == 401
      $stderr.puts "Authentication required! Getting token..."
      token = v2_login(response.headers['Www-Authenticate'])
      repository_tags_v2(repository, token)
    elsif response.status == 200
      body = JSON.load(response.body)
      body['tags']
    else
      raise response.inspect
    end
  end

  def is_official_registry?(repository)
    return @base_uri == OFFICIAL_URL
  end

  def uri_for_repository_path(repository, path)
    if repository.match(/\A([a-z0-9]+[a-z0-9\-\.]+(?::[1-9][0-9]*)?)\/(.*)\z/)
      host = $1
      short_image_name = $2
      "https://#{host}#{path.gsub(repository, short_image_name)}"
    else
      @base_uri + path
    end
  end
end
