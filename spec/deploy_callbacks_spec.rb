require 'spec_helper'
require 'centurion'

RSpec.describe Centurion::DeployCallbacks do
  shared_examples_for 'a callback' do
    let(:server) { double :server }
    let(:service) { double :service }

    let(:klass) do
      Class.new do
        include Centurion::DeployCallbacks
        def method_missing(method_name, *_args)
          doing method_name
        end
      end
    end

    let(:object) do
      klass.new
    end

    before do
      allow(object).to receive(:emit)
    end
  end

  shared_examples_for 'the before_stopping_container callbacks' do |callback, method_name|
    include_examples 'a callback'

    it 'invokes all the callbacks' do
      expect(object).to receive(:emit).with(callback, server, service).ordered
      expect(object).to receive(:doing).with(method_name).ordered
      subject
    end
  end

  shared_examples_for 'the before_starting_container callbacks' do |callback|
    include_examples 'a callback'

    it 'invokes all the callbacks' do
      expect(object).to receive(:emit).with(callback, server, service).ordered
      subject
    end
  end

  shared_examples_for 'the after_starting_container callbacks' do |callback, method_name|
    include_examples 'a callback'

    it 'invokes all the callbacks' do
      expect(object).to receive(:doing).with(method_name).ordered
      expect(object).to receive(:emit).with(callback, server, service).ordered
      subject
    end
  end

  shared_examples_for 'the after_health_check_ok callbacks' do |callback, method_name|
    include_examples 'a callback'

    it 'invokes all the callbacks' do
      expect(object).to receive(:doing).with(method_name).ordered
      expect(object).to receive(:emit).with(callback, server).ordered
      subject
    end
  end

  describe 'the before_stopping_container callback' do
    subject { object.stop_containers server, service }
    it_behaves_like 'the before_stopping_container callbacks',
                    :before_stopping_container,
                    :stop_containers
  end

  describe 'before_starting_container callback' do 
    subject { object.before_starting_container server, service }
    it_behaves_like 'the before_starting_container callbacks',
                    :before_starting_container
  end

  describe 'after started callback' do
    subject { object.start_new_container server, service, double }
    it_behaves_like 'the after_starting_container callbacks',
                    :after_starting_container,
                    :start_new_container
  end

  describe 'after health check ok callback' do
    let(:args) do
      [
        double(:health_check_method),
        server,
        double(:port),
        double(:endpoint),
        double(:image_id),
        double(:tag),
        double(:sleep),
        double(:retries)
      ]
    end
    subject { object.wait_for_health_check_ok(*args) }
    it_behaves_like 'the after_health_check_ok callbacks',
                    :after_health_check_ok,
                    :wait_for_health_check_ok
  end
end
