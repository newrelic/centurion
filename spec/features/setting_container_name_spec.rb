require 'fileutils'
require 'docker'

RSpec.describe 'Setting the container name', type: :integration do
  let(:docker_url) { 'tcp://10.11.11.111:4243' }
  let(:centurion) { File.join File.dirname(__FILE__), '..', '..', 'bin', 'centurion' }

  around do |example|
    FileUtils.cd File.dirname(__FILE__) do
      Docker.url =  'tcp://10.11.11.111:4243'
      Docker::Container.all(all: true).each { |c| c.delete(force: true) }
      example.run
      Docker::Container.all(all: true).each { |c| c.delete(force: true) }
    end
  end

  it 'starts a container with the custom set name' do
    `#{centurion} --project fixture --environment rename_container --action deploy 2>/dev/null`
    container_names = Docker::Container.all.map{ |c| c.info["Names"] }.flatten
    expect(container_names).to include(%r{^/new-container-name-[a-f0-9]{14}})
  end
end
