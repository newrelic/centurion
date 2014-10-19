require 'excon'
require 'json'
require 'uri'

module Centurion; end

class Centurion::DockerRegistry
  OFFICIAL_URL = 'https://registry.hub.docker.com'

  def initialize(base_uri, registry_user=nil, registry_password=nil)
    @base_uri = base_uri
    @user = registry_user
    @password = registry_password
  end

  def digest_for_tag(repository, tag)
    path = "/v1/repositories/#{repository}/tags/#{tag}"
    uri = uri_for_repository_path(repository, path)
    $stderr.puts "GET: #{uri}"
    options = { :headers => { "Content-Type" => "application/json" } }
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
    path = "/v1/repositories/#{repository}/tags"
    uri = uri_for_repository_path(repository, path)

    $stderr.puts "GET: #{uri.inspect}"
    options = {}
    if @user
      options[:user] = @user
      options[:password] = @password
    end
    response = Excon.get(
      uri,
      options
    )
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
