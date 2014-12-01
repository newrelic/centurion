require 'spec_helper'
require 'capistrano_dsl'

class DSLTest
  extend Capistrano::DSL
end

describe Capistrano::DSL do
  before do
    DSLTest.clear_env
  end

  context 'handling multiple environments' do
    it 'sets the environment' do
      expect { DSLTest.set_current_environment(:test) }.not_to raise_error
    end

    it 'fetchs the current environment' do
      DSLTest.set_current_environment(:test)
      expect(DSLTest.current_environment).to eq(:test)
    end
  end

  context 'without a current environment set' do
    it 'dies if the current_environment is not set' do
      expect { DSLTest.set(:foo, 'asdf') }.to raise_error(Capistrano::DSL::CurrentEnvironmentNotSetError)
    end
  end

  context 'with a current environment set' do
    before do
      DSLTest.set_current_environment(:test)
    end

    it 'stores variables in the environment' do
      expect { DSLTest.set(:foo, 'bar') }.not_to raise_error
      expect(DSLTest).to have_key_and_value(:foo, 'bar')
    end

    it 'deletes keys from the environment' do
      DSLTest.set(:foo, 'bar')
      expect(DSLTest).to have_key_and_value(:foo, 'bar')
      DSLTest.delete(:foo)
      expect(DSLTest.fetch(:foo)).to be_nil
    end

    it 'returns true for any? when the value exists' do
      DSLTest.set(:foo, 'bar')
      expect(DSLTest.any?(:foo)).to be_truthy
    end

    it 'returns false for any? when the value does not exist' do
      expect(DSLTest.any?(:foo)).to be_falsey
    end

    it 'passes through the any? method to values that support it' do
      class NoAny
        def any?
          'oh no'
        end
      end

      DSLTest.set(:foo, NoAny.new)
      expect(DSLTest.any?(:foo)).to eq('oh no')
    end
  end
end
