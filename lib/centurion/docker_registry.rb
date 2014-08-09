require 'excon'
require 'json'
require 'uri'

module Centurion; end

class Centurion::DockerRegistry
  OFFICIAL_URL = 'https://registry.hub.docker.com/'

  def initialize(base_uri)
    @base_uri = base_uri
  end

  def digest_for_tag(repository, tag)
    path = "/v1/repositories/#{repository}/tags/#{tag}"
    $stderr.puts "GET: #{path.inspect}"
    response = Excon.get(
      @base_uri + path,
      :headers => { "Content-Type" => "application/json" }
    )
    raise response.inspect unless response.status == 200

    # This hack is stupid, and I hate it. But it works around the fact that
    # the Docker Registry will return a base JSON String, which the Ruby parser
    # refuses (possibly correctly) to handle
    JSON.load('[' + response.body + ']').first
  end

  def repository_tags(repository)
    path = "/v1/repositories/#{repository}/tags"
    $stderr.puts "GET: #{@base_uri + path}"
    response = Excon.get(@base_uri + path)
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

    if @base_uri == OFFICIAL_URL
      {}.tap do |hash|
        tags.each do |tag|
          hash[tag['name']] = tag['layer']
        end
      end
    else
      tags
    end
  end
end
