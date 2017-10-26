require 'simplecov'
SimpleCov.start do
  add_filter '/spec'
end

require 'excon'

RSpec.configure do |config|
  # Mock by default
  config.before(:all) do
    Excon.defaults[:mock] = true
  end

  config.after(:each) do
    Excon.stubs.clear
  end
end

$: << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|f| require f}
