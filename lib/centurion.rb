Dir[File.join(File.dirname(__FILE__), 'core_ext', '*')].each do |file|
  require file
end

Dir[File.join(File.dirname(__FILE__), 'centurion', '*')].each do |file|
  require file
end

module Centurion; end
