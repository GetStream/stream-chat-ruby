# frozen_string_literal: true

require 'bundler/gem_tasks'
# rake spec
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) { |t| t.verbose = false }

# rake console
task :console do
  require 'pry'
  require 'stream-chat'
  ARGV.clear
  Pry.start
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

task default: [:spec]
task test: [:spec]
