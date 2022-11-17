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
  gem.authors = ['getstream.io']
  gem.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|sorbet|spec|\.github|scripts|assets)/}) }
  end
  gem.required_ruby_version = '>=2.5.0'
  gem.metadata = {
    'rubygems_mfa_required' => 'false',
    'homepage_uri' => 'https://getstream.io/chat/docs/',
    'bug_tracker_uri' => 'https://github.com/GetStream/stream-chat-ruby/issues',
    'documentation_uri' => 'https://getstream.io/chat/docs/ruby/?language=ruby',
    'changelog_uri' => 'https://github.com/GetStream/stream-chat-ruby/blob/master/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/GetStream/stream-chat-ruby'
  }

  gem.add_dependency 'faraday', '~> 1.10.0'
  gem.add_dependency 'faraday-multipart', '~> 1.0.3'
  gem.add_dependency 'faraday-net_http_persistent', '~> 1.2'
  gem.add_dependency 'jwt', '~> 2.3'
  gem.add_dependency 'net-http-persistent', '~> 4.0'
  gem.add_dependency 'sorbet-runtime', '~> 0.5.10539'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rspec', '~> 3.12'
  gem.add_development_dependency 'simplecov', '~> 0.21.2'
  gem.add_development_dependency 'simplecov-console', '~> 0.9.1'
end
