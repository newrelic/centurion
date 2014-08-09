require 'spec_helper'
require 'centurion/docker_registry'

describe Centurion::DockerRegistry do
  let(:registry_url) { 'http://localhost/' }
  let(:registry) { Centurion::DockerRegistry.new(registry_url) }

  describe '#repository_tags' do
    let(:repository) { 'foobar' }
    let(:tag_name) { 'arbitrary_tag' }
    let(:image_id) { 'deadbeef0000' }

    before do
      expect(Excon).to receive(:get).
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
  end
end
