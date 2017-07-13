#!/usr/bin/env rake

require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

task default: 'test:all'

desc 'Run IRB with the gem environment loaded'
task :console do
  puts '[+] Loading development console...'
  system('irb -r ./lib/ruumba.rb')
end

desc 'Run tests'
task :spec do
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern    = './spec/**/*_spec.rb'
    t.rspec_opts = ['--color --format d']
  end
end

desc 'Lint'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.patterns = %w(lib/**/*.rb spec/**/*.rb)
end

desc 'Run all the tests, lint all the things'
namespace :test do
  task all: %i(spec rubocop)
end
