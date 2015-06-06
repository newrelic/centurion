require 'spec_helper'
require 'centurion'

RSpec.describe Centurion::DeployCallbacks do
  describe 'before stopping callback' do
    let(:callback) { [double, double] }
    let(:klass) do
      Class.new do
        prepend Centurion::DeployCallbacks
        def stop_containers(server, service, timeout)
          doing_it_now server, service, timeout
        end
      end
    end
    let(:object) do
      klass.new.tap do |o|
        allow(o).to receive(:fetch)
          .with(:before_stopping_container_callbacks, [])
          .and_return callbacks
      end
    end
    let(:server) { double :server }
    let(:service) { double :service }
    let(:timeout) { double :timeout }
    let(:callbacks) { [double, double] }

    it 'invokes all the callback before stopping the container' do
      callbacks.each do |callback|
        expect(callback).to receive(:call)
          .with(server)
          .ordered
      end
      expect(object).to receive(:doing_it_now)
        .with(server, service, timeout)
        .ordered

      object.stop_containers server, service, timeout
    end
  end
end
