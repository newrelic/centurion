require 'spec_helper'
require 'centurion/dogestry'

describe Centurion::Dogestry do
  let(:dogestry_options) {
    {
      aws_access_key_id: "abc",
      aws_secret_key: "xyz",
      s3_bucket: "s3-registry-test"
    }
  }
  let(:registry) { Centurion::Dogestry.new(dogestry_options) }
  let(:repo) { 'google/golang' }

  describe '#aws_access_key_id' do
    it 'returns correct value' do
      registry.aws_access_key_id.should == dogestry_options[:aws_access_key_id]
    end
  end

  describe '#aws_secret_key' do
    it 'returns correct value' do
      registry.aws_secret_key.should == dogestry_options[:aws_secret_key]
    end
  end

  describe '#s3_bucket' do
    it 'returns correct value' do
      registry.s3_bucket.should == dogestry_options[:s3_bucket]
    end
  end

  describe '#s3_region' do
    it 'returns correct default value' do
      registry.s3_region.should == "us-east-1"
    end
  end

  describe '#s3_url' do
    it 'returns correct value' do
      registry.s3_url.should == "s3://#{registry.s3_bucket}/?region=#{registry.s3_region}"
    end
  end

  describe '#exec_command' do
    it 'returns correct value' do
      registry.exec_command('pull', repo).should start_with('dogestry')
    end
  end

  describe '#which' do
    it 'finds dogestry command line' do
      allow(File).to receive(:executable?).and_return(true)
      registry.which('dogestry').should_not == nil
    end
  end
end
