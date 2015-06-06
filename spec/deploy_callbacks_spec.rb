require 'spec_helper'
require 'centurion'

RSpec.describe Centurion::DeployCallbacks do
  let(:server) { double :server }
  let(:service) { double :service }
  let(:callbacks) { [double, double] }

  let(:klass) do
    Class.new do
      prepend Centurion::DeployCallbacks
      def stop_containers(server, service, timeout)
        stopping_it_now server, service, timeout
      end

      def start_new_container(server, service, restart_policy)
        starting_it_now server, service, restart_policy
      end
    end
  end

  describe 'before stopping callback' do
    let(:object) do
      klass.new.tap do |o|
        allow(o).to receive(:fetch)
          .with(:before_stopping_image_callbacks, [])
          .and_return callbacks
      end
    end
    let(:timeout) { double :timeout }
    it 'invokes all the callback before stopping the container' do
      callbacks.each do |callback|
        expect(callback).to receive(:call)
          .with(server)
          .ordered
      end
      expect(object).to receive(:stopping_it_now)
        .with(server, service, timeout)
        .ordered

      object.stop_containers server, service, timeout
    end
  end

  describe 'after started callback' do
    let(:object) do
      klass.new.tap do |o|
        allow(o).to receive(:fetch)
          .with(:after_image_started_callbacks, [])
          .and_return callbacks
      end
    end
    let(:restart_policy) { double }
    it 'invokes all the callbacks after the container is started' do
      expect(object).to receive(:starting_it_now)
        .with(server, service, restart_policy)
        .ordered
      callbacks.each do |callback|
        expect(callback).to receive(:call)
          .with(server)
          .ordered
      end

      object.start_new_container server, service, restart_policy
    end
  end
end
