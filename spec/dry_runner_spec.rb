require 'spec_helper'
require 'pry'

describe Centurion::DryRunner do
  before do
    Singleton.__init__(Capistrano::DSL::Env::Store)
  end

  before do
    env[:current_environment] = :test
    env[:test] = {
      project: 'test_project',
      hosts: %w(example.com)
    }
  end

  let(:env) do
    Singleton.__init__(Capistrano::DSL::Env::Store).instance
  end

  subject { described_class.new(env).send(:result) }

  context 'nothing is present' do
    it 'does not error out' do
      expect(subject).to eql 'docker -H=tcp://example.com:2375 run'
    end
  end

  context 'with environment variables' do
    before do
      env[:test][:env_vars] = { 'hello' => 'world' }
    end
    it 'prints out the host' do
      expect(subject).to match(/hello='world'/)
    end
  end

  context 'with ports' do
    before do
      env[:test][:port_bindings] = [Centurion::Service::PortBinding.new(23, 32, 'foo', '0.0.0.0')]
    end

    it 'prints out the host' do
      expect(subject).to match(%r{-p 23:32/foo})
    end
  end
end
