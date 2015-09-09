require 'spec_helper'
require 'centurion/docker_registry'

describe Centurion::DockerRegistry do
  let(:registry_url) { 'http://localhost/' }
  let(:registry)     { Centurion::DockerRegistry.new(registry_url) }

  describe '#repository_tags' do
    let(:repository) { 'foobar' }
    let(:tag_name)   { 'arbitrary_tag' }
    let(:image_id)   { 'deadbeef0000' }
    let(:url)        { any_args() }

    before do
      expect(Excon).to receive(:get).with(url).and_return(
        double(status: 200, body: response)
      )
    end

    subject { registry.repository_tags(repository) }

    describe 'handling different responses from open source and official registries' do
      context 'when given a response from the official Docker registry' do
        let(:registry_url) { Centurion::DockerRegistry::OFFICIAL_URL }
        let(:response)     { <<-JSON.strip }
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

    context 'when given the official Docker registry and a repository with a hostname' do
      let(:registry_url) { Centurion::DockerRegistry::OFFICIAL_URL }
      let(:repository)   { 'docker-reg.example.com/foobar' }
      let(:response)     { <<-JSON.strip }
        [{"layer": "#{image_id}", "name": "#{tag_name}"}]
      JSON

      it 'fetches from the image-referenced registry' do
        expect(subject).to eq(tag_name => image_id)
      end
    end

    context 'when given any other registry' do
      let(:registry_url) { 'http://my-registry.example.com' }
      let(:response)     { <<-JSON.strip }
        {"#{tag_name}": "#{image_id}"}
      JSON

      context 'and a repository with a hostname' do
        let(:repository) { 'docker-reg.example.com/foobar' }

        it 'fetches from the image-referenced registry' do
          expect(subject).to eq(tag_name => image_id)
        end
      end

      context 'and a repository with no hostname' do
        let(:repository) { 'foobar' }

        it 'fetches from the image-referenced registry' do
          expect(subject).to eq(tag_name => image_id)
        end
      end
    end
  end

  describe '#repository_auth' do
    let(:tag_name)   { 'arbitrary_tag' }
    let(:image_id)   { 'deadbeef0000' }
    let(:user)       { 'user_foo' }
    let(:password)   { 'pass_bar' }
    let(:registry)     { Centurion::DockerRegistry.new(registry_url, user, password) }

    context 'when authentication data is provided to the DockerRegistry object' do
      let(:registry_url) { Centurion::DockerRegistry::OFFICIAL_URL }
      let(:repository)   { 'docker-reg.example.com/foobar' }
      let(:response)     { <<-JSON.strip }
        [{"layer": "#{image_id}", "name": "#{tag_name}"}]
      JSON

      before do
        expect(Excon).to receive(:get).with(kind_of(String), hash_including(user: user, password: password)).and_return(
          double(status: 200, body: response)
        )
      end
      it 'uses it to connect to the registry' do
        registry.repository_tags(repository)
      end
    end
  end
end
