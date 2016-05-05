Dir[File.join(File.dirname(__FILE__), 'core_ext', '*')].each do |file|
  require File.realpath(file)
end

Dir[File.join(File.dirname(__FILE__), 'centurion', '*')].each do |file|
  require File.realpath(file)
end

module Centurion; end
