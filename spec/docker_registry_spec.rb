require 'spec_helper'
require 'centurion/docker_registry'

describe Centurion::DockerRegistry do
  let(:registry_url) { 'http://localhost/' }
  let(:registry) { Centurion::DockerRegistry.new(registry_url) }

  describe '#repository_tags' do
    let(:repository) { 'foobar' }
    let(:tag_name) { 'arbitrary_tag' }
    let(:image_id) { 'deadbeef0000' }
    let(:url) { any_args() }

    before do
      expect(Excon).to receive(:get).
                       with(url).
                       and_return(double(status: 200, body: response))
    end

    subject { registry.repository_tags(repository) }

    context 'when given a response from the official Docker registry' do
      let(:registry_url) { Centurion::DockerRegistry::OFFICIAL_URL }
      let(:response) { <<-JSON.strip }
        [{"layer": "#{image_id}", "name": "#{tag_name}"}]
      JSON

      it 'normalizes the response' do
        expect(subject).to eq(tag_name => image_id)
      end
    end

    context 'when given a response from the open-source Docker registry' do
      let(:response) { <<-JSON.strip }
        {"#{tag_name}": "#{image_id}"}
      JSON

      it 'normalizes the response' do
        expect(subject).to eq(tag_name => image_id)
      end
    end

    context 'when given the official Docker registry and a repository with a host name' do
      let(:registry_url) { Centurion::DockerRegistry::OFFICIAL_URL }
      let(:repository) { 'docker-reg.example.com/foobar' }

      let(:response) { <<-JSON.strip }
        {"#{tag_name}": "#{image_id}"}
      JSON

      let(:url) { 'https://docker-reg.example.com/v1/repositories/foobar/tags' }

      it 'fetches from the image-referenced registry' do
        expect(subject).to eq(tag_name => image_id)
      end
    end
  end

end
