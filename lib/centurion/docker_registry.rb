require 'excon'
require 'json'
require 'uri'

module Centurion; end

class Centurion::DockerRegistry
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
    $stderr.puts "GET: #{path.inspect}"
    response = Excon.get(@base_uri + path)
    raise response.inspect unless response.status == 200
    JSON.load(response.body)
  end
end
