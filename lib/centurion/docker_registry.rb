require 'excon'
require 'json'
require 'uri'

module Centurion; end

class Centurion::DockerRegistry
  def initialize()
    # @base_uri = "https://staging-docker-registry.nr-ops.net"
    @base_uri = 'http://chi-docker-registry.nr-ops.net'
  end
  
  def digest_for_tag( repository, tag)
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
  
  def respository_tags( respository )
    path = "/v1/repositories/#{respository}/tags"
    $stderr.puts "GET: #{path.inspect}"
    response = Excon.get(@base_uri + path)
    raise response.inspect unless response.status == 200
    JSON.load(response.body)
  end
end
