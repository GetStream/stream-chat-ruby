lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stream-chat/version'

Gem::Specification.new do |gem|
  gem.name = 'stream-chat-ruby'
  gem.description = ''
  gem.version = StreamChat::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.summary = ''
  gem.email = 'support@getstream.io'
  gem.homepage = 'http://github.com/GetStream/stream-chat-ruby'
  gem.authors = ['Mircea Cosbuc']
  gem.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  
  gem.add_dependency 'faraday'
  gem.add_dependency 'jwt'
  gem.add_dependency 'rake'
  gem.add_dependency 'rspec'
  gem.add_dependency 'simplecov'
end
