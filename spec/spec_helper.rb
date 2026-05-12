require 'simplecov'
require 'simplecov-console'

SimpleCov.start do
  formatter SimpleCov::Formatter::Console
  add_filter '/spec/'
end

# Autoload everything under spec/support — custom RSpec matchers, shared
# contexts, fixtures, etc.
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }
