require 'simplecov'
require 'simplecov-console'

SimpleCov.start do
  formatter SimpleCov::Formatter::Console
  add_filter '/spec/'
end
