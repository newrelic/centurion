require 'docker'

module Centurion::Api

  #
  # opts - Hash of values to pass into the Docker::Container.all method. Such as :all => true which will return all containers
  #
  def self.get_containers_by_port(host, public_port, opts = {})
    containers = []
    Docker::Container.all(opts, host).each do |container|
      container = Docker::Container.get(container.id, {}, container.connection)
      container.json["NetworkSettings"]["Ports"].keys.each do |port|
        port_mapping = container.json["NetworkSettings"]["Ports"][port]
        containers << container if port_mapping && port_mapping.first["HostPort"] == public_port
      end
    end
    containers
  end

  def self.get_all_tags_for_image(host, image)
    tags = []
    Docker::Image.all({}, host).each do |i|
      if image.id == i.id
        repo_tags = i.info["RepoTags"]
        repo_tags.each do |tag|
          tags << tag.split(/:/).last
        end
      end
    end
    tags
  end

  def self.get_all_images_by_name(host, image_name)
    images = []
    Docker::Image.all({}, host).each do |image|
      images << image if tag_matches_image_name?(image_name, image.info["RepoTags"])
    end
    images
  end

  def self.get_image_by_container(host, container)
    Docker::Image.all({}, host).each do |image|
      return image if image.id == container.json["Image"]
    end
  end

  def self.get_all_non_running_non_paused_containers(host)
    containers = []
    Docker::Container.all({:all => true}, host).each do |container|
      container = Docker::Container.get(container.id, {}, container.connection)
      state = container.json["State"]
      containers << container if state["Running"] == false && state["Paused"] == false
    end
    containers
  end

  def self.get_non_running_containers(host)
    containers = []
    Docker::Container.all({:all => true}, host).each do |container|
      container = Docker::Container.get(container.id, {}, container.connection)
      state = container.json["State"]
      containers << container if state["Running"] == false && state["Paused"] == false
    end
    containers
  end

  def self.tag_matches_image_name?(image_name, tags)
    image_name == tags.first.split(/:/).first
  end


end