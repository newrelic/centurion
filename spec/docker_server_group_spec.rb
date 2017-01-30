require 'spec_helper'
require 'centurion/docker_server'
require 'centurion/docker_server_group'

describe Centurion::DockerServerGroup do
  let(:docker_path) { 'docker' }
  let(:group) { Centurion::DockerServerGroup.new(['host1', 'host2'], docker_path) }

  it 'takes a hostlist and instantiates DockerServers' do
    expect(group.hosts.length).to equal(2)
    expect(group.hosts.first).to be_a(Centurion::DockerServer)
    expect(group.hosts.last).to be_a(Centurion::DockerServer)
  end

  it 'implements Enumerable' do
    expect(group.methods).to be_a_kind_of(Enumerable)
  end

  it 'prints a friendly message to stderr when iterating' do
    expect(group).to receive(:info).with(/Connecting to Docker on host[0-9]/).twice

    group.each { |host| }
  end

  it 'can run parallel operations' do
    item = double('item', dummy_method: true)
    expect(item).to receive(:dummy_method).twice

    expect { group.each_in_parallel { |host| item.dummy_method } }.not_to raise_error
  end
  
  describe '#get_current_hosts_by_tag_for' do
    let(:docker_path) { 'docker' }
    let(:docker_server_1) { Centurion::DockerServer.new('host1', docker_path) }
    let(:docker_server_2) { Centurion::DockerServer.new('host2', docker_path) }
    let(:docker_server_3) { Centurion::DockerServer.new('host3', docker_path) }
    let(:docker_server_group) {
      docker_server_group = Centurion::DockerServerGroup.new(['placeholder'], docker_path)
      docker_server_group.instance_variable_set(:@hosts, [ docker_server_1, docker_server_2, docker_server_3 ])
      docker_server_group
    }

    it 'raises when a server has multiple tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1", "tag2"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag1"])

      expect { docker_server_group.get_current_hosts_by_tag_for("image") }.to raise_error
    end

    it 'raises when there are duplicate server entries' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:hostname).and_return('host1')
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag1"])

      expect { docker_server_group.get_current_hosts_by_tag_for("image") }.to raise_error
    end

    it 'returns no hosts when tags are empty' do
      allow(docker_server_1).to receive(:current_tags_for).and_return([])
      allow(docker_server_2).to receive(:current_tags_for).and_return([])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])

      actual_results = docker_server_group.get_current_hosts_by_tag_for("image")
      expected_results = ({})
      expect(actual_results).to eq expected_results
    end

    it 'maps servers by tag' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag2"])

      actual_results = docker_server_group.get_current_hosts_by_tag_for("image")
      expected_results = ({ "tag1" => [docker_server_1, docker_server_2], "tag2" => [docker_server_3] })
      expect(actual_results).to eq expected_results
    end
  end

  describe '#find_existing_canary_for' do
    let(:docker_path) { 'docker' }
    let(:docker_server_1) { Centurion::DockerServer.new('host1', docker_path) }
    let(:docker_server_2) { Centurion::DockerServer.new('host2', docker_path) }
    let(:docker_server_3) { Centurion::DockerServer.new('host3', docker_path) }
    let(:docker_server_4) { Centurion::DockerServer.new('host4', docker_path) }
    let(:docker_server_group) {
      docker_server_group = Centurion::DockerServerGroup.new(['placeholder'], docker_path)
      docker_server_group.instance_variable_set(:@hosts, [ docker_server_1, docker_server_2, docker_server_3, docker_server_4 ])
      docker_server_group
    }

    it 'raises when there are no servers with the image' do
      allow(docker_server_1).to receive(:current_tags_for).and_return([])
      allow(docker_server_2).to receive(:current_tags_for).and_return([])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end

    it 'raises when there is only one server with the image' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return([])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end
  
    it 'raises when there are only two servers with the image and one tag' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end

    it 'raises when there are only two servers with the image and two tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end

    it 'raises when there are more than two tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag3"])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end

    it 'raises when there are no tags deployed to only one server' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_4).to receive(:current_tags_for).and_return(["tag2"])

      expect { docker_server_group.find_existing_canary_for("image") }.to raise_error
    end

    it 'finds no canary when there is only one tag' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect(docker_server_group.find_existing_canary_for("image")).to be_nil 
    end

    it 'finds a canary' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_4).to receive(:current_tags_for).and_return(["tag1"])
      
      expect(docker_server_group.find_existing_canary_for("image")).to eq ({ tag: 'tag2', server: docker_server_3 })
    end
  end

  describe '#get_currently_deployed_tag' do
    let(:docker_path) { 'docker' }
    let(:docker_server_1) { Centurion::DockerServer.new('host1', docker_path) }
    let(:docker_server_2) { Centurion::DockerServer.new('host2', docker_path) }
    let(:docker_server_3) { Centurion::DockerServer.new('host3', docker_path) }
    let(:docker_server_4) { Centurion::DockerServer.new('host4', docker_path) }
    let(:docker_server_group) {
      docker_server_group = Centurion::DockerServerGroup.new(['placeholder'], docker_path)
      docker_server_group.instance_variable_set(:@hosts, [ docker_server_1, docker_server_2, docker_server_3, docker_server_4 ])
      docker_server_group
    }

    it 'raises when there are no servers with the image' do
      allow(docker_server_1).to receive(:current_tags_for).and_return([])
      allow(docker_server_2).to receive(:current_tags_for).and_return([])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end

    it 'raises when there is only one server with the image' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return([])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end
  
    it 'raises when there are only two servers and one tag' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end

    it 'raises when there are only two servers and two tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_3).to receive(:current_tags_for).and_return([])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end

    it 'raises when there are more than two tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag3"])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end

    it 'raises when there are no tags deployed to only one server' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_4).to receive(:current_tags_for).and_return(["tag2"])

      expect { docker_server_group.get_currently_deployed_tag("image") }.to raise_error
    end

    it 'returns the only tag when there is only one tag' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect(docker_server_group.get_currently_deployed_tag("image")).to eq "tag1"
    end

    it 'returns non-canary tag when there are two tags' do
      allow(docker_server_1).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_2).to receive(:current_tags_for).and_return(["tag1"])
      allow(docker_server_3).to receive(:current_tags_for).and_return(["tag2"])
      allow(docker_server_4).to receive(:current_tags_for).and_return([])

      expect(docker_server_group.get_currently_deployed_tag("image")).to eq "tag2"
    end
  end

end
