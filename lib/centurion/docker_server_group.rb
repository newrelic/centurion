require_relative 'docker_server'
require_relative 'logging'

module Centurion; end

class Centurion::DockerServerGroup
  include Enumerable
  include Centurion::Logging

  attr_reader :hosts

  def initialize(hosts, docker_path, tls_params = {})
    raise ArgumentError.new('Bad Host list!') if hosts.nil? || hosts.empty?
    @hosts = hosts.map do |hostname|
      Centurion::DockerServer.new(hostname, docker_path, tls_params)
    end
  end

  def each(&block)
    @hosts.each do |host|
      info "----- Connecting to Docker on #{host.hostname} -----"
      block.call(host)
    end
  end

  def each_in_parallel(&block)
    threads = @hosts.map do |host|
      Thread.new { block.call(host) }
    end

    threads.each { |t| t.join }
  end

  def get_current_tags_for(image)
    return @hosts
      .map { |host| ({ server: host.hostname, tags: host.current_tags_for(image) }) }
      .filter { |host| host.tags }
  end

  def get_current_hosts_by_tag_for(image)
    # ensure each server is only listed once
    duplicate_hosts = @hosts
      .group_by { |host| host.hostname }
      .select { |hostname, hosts| hosts.size > 1 }
    if duplicate_hosts.size != 0
      raise "Found duplicate entries for a server: #{duplicate_hosts}"
    end

    # get all of the hosts that have the specified image already
    host_and_tags_list = @hosts
      .map { |host| ({ host: host, tags: host.current_tags_for(image) }) }
      .select { |host_and_tags| host_and_tags[:tags].size > 0 }

    # ensure each server has only one tag
    hosts_with_multiple_tags = host_and_tags_list
      .select { |host_and_tags| host_and_tags[:tags].size > 1 }
    if hosts_with_multiple_tags.size != 0
      raise "Found servers that had multiple tags: #{servers_with_multiple_tags}"
    end
    host_and_tag_list = host_and_tags_list
      .map { |host_and_tags| ({ host: host_and_tags[:host], tag: host_and_tags[:tags][0] }) }

    # return a map of servers associated with each tag like: { "tag1": ["host1","host2"], "tag2": ["host3"] }
    hosts_by_tag = host_and_tag_list
      .group_by { |host_and_tag| host_and_tag[:tag] }
      .map { |tag, host_and_tag_grouping| [ tag, host_and_tag_grouping.map { |host_and_tag| host_and_tag[:host] } ] }
      .to_h
    hosts_by_tag
  end

  def find_existing_canary_for(image)
    deployed_hosts_by_tag = get_current_hosts_by_tag_for(image)

    # ensure enough servers to do a canary
    if deployed_hosts_by_tag.values.flatten.size < 3
      raise "Cannot canary to less than 3 servers because we wouldn't be able to tell which one was the canary once deployed."
    end

    # if there is only one image across all of the servers then canary to the first
    if deployed_hosts_by_tag.size == 1
      return nil
    end

    # ensure that there are only two different images deployed
    if deployed_hosts_by_tag.size > 2
      raise "There currently are more than 2 different docker images deployed right now.  Canary deployments can only happen in an environment that has either one or two different images deployed to it."
    end

    # get the tag for the current canary
    canary_tag = deployed_hosts_by_tag.select { |tag, hosts| hosts.size == 1 }.keys.first

    # ensure that there is an existing canary
    if canary_tag.nil?
      raise "Each of the two currently deployed docker images is deployed to 2 or more hosts so we cannot identify which server is the canary."
    end

    # return the existing canary server
    return { tag: canary_tag, server: deployed_hosts_by_tag[canary_tag].first }
  end

  def get_currently_deployed_tag(image)
    deployed_hosts_by_tag = get_current_hosts_by_tag_for(image)
  
    # if there is not a canary out then return the only tag or raise an error if the environment is in a bad state
    canary_server = find_existing_canary_for(image)
    if canary_server.nil?
      return deployed_hosts_by_tag.keys.first
    end

    # return the other tag (the one that isn't the canary)
    return deployed_hosts_by_tag.keys.select { |tag| tag != canary_server[:tag] }.first
  end
end
