# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stream-chat/version'

Gem::Specification.new do |gem|
  gem.name = 'stream-chat-ruby'
  gem.description = 'Ruby client for Stream Chat.'
  gem.version = StreamChat::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.summary = 'The low level client for serverside calls for Stream Chat.'
  gem.email = 'support@getstream.io'
  gem.homepage = 'http://github.com/GetStream/stream-chat-ruby'
  gem.authors = ['Mircea Cosbuc']
  gem.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  gem.required_ruby_version = '>=2.5.0'

  gem.add_dependency 'faraday'
  gem.add_dependency 'jwt'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'simplecov'
  gem.metadata['rubygems_mfa_required'] = 'true'
end
