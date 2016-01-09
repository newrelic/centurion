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

  shared_examples_for 'a before callback' do |callback, method_name|
    include_examples 'a callback'

    it 'invokes all the callback before the method' do
      expect(object).to receive(:emit).with(callback, server).ordered
      expect(object).to receive(:doing).with(method_name).ordered
      subject
    end
  end

  shared_examples_for 'an after callback' do |callback, method_name|
    include_examples 'a callback'

    it 'invokes all the callback before the method' do
      expect(object).to receive(:doing).with(method_name).ordered
      expect(object).to receive(:emit).with(callback, server).ordered
      subject
    end
  end

  describe 'before stopping callback' do
    subject { object.stop_containers server, service }
    it_behaves_like 'a before callback',
                    :before_stopping_image,
                    :stop_containers
  end

  describe 'after started callback' do
    subject { object.start_new_container server, service, double }
    it_behaves_like 'an after callback',
                    :after_image_started,
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
    it_behaves_like 'an after callback',
                    :after_health_check_ok,
                    :wait_for_health_check_ok
  end
end
