$: << File.expand_path("lib")
require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w[--color --format=documentation]
    t.pattern = "spec/**/*_spec.rb"
    t.exclude_pattern = 'spec/features/**'
  end

  RSpec::Core::RakeTask.new(:integration) do |t|
    t.rspec_opts = %w( --color --format=documentation --tag type:integration )
    t.pattern = 'spec/**/*_spec.rb'
  end

  task :default => [:spec]
rescue LoadError
  # don't generate Rspec tasks if we don't have it installed
end
