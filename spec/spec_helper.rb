require 'simplecov'
SimpleCov.start do
  add_filter '/spec'
end

$: << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|f| require f}
