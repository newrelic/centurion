# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'centurion/version'

Gem::Specification.new do |spec|
  spec.name          = 'centurion'
  spec.version       = Centurion::VERSION
  spec.authors       = [
    'Nic Benders', 'Karl Matthias', 'Andrew Bloomgarden', 'Aaron Bento',
    'Paul Showalter', 'David Kerr', 'Jonathan Owens', 'Jon Guymon',
    'Merlyn Albery-Speyer', 'Amjith Ramanujam', 'David Celis', 'Emily Hyland',
    'Bryan Stearns', 'Sean P. Kane']
  spec.email         = [
    'nic@newrelic.com', 'kmatthias@newrelic.com', 'andrew@newrelic.com',
    'aaron@newrelic.com', 'poeslacker@gmail.com', 'dkerr@newrelic.com',
    'jonathan@newrelic.com', 'jon@newrelic.com', 'merlyn@newrelic.com',
    'amjith@newrelic.com', 'dcelis@newrelic.com', 'ehyland@newrelic.com',
    'bryan@newrelic.com', 'skane@newrelic.com']
  spec.summary       = <<-EOS.gsub(/^\s+/, '')
    A deployment tool for Docker. Takes containers from a Docker registry and
    runs them on a fleet of hosts with the correct environment variables, host
    mappings, and port mappings. Supports rolling deployments out of the box, and
    makes it easy to ship applications to Docker servers.

    We're using it to run our production infrastructure.
  EOS
  spec.homepage      = 'https://github.com/newrelic/centurion'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'trollop'
  spec.add_dependency 'excon', '~> 0.33'
  spec.add_dependency 'logger-colors'
  spec.add_dependency 'net-ssh'
  spec.add_dependency 'rbnacl'
  spec.add_dependency 'rbnacl-libsodium'
  spec.add_dependency 'bcrypt_pbkdf'
  spec.add_dependency 'sshkit'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake', '~> 10.5'
  spec.add_development_dependency 'rspec', '~> 3.1.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'simplecov'

  spec.required_ruby_version = '>= 1.9.3'
end
