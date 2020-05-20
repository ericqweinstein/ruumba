# @author Eric Weinstein <eric.q.weinstein@gmail.com>

# Test coverage report
require 'simplecov'
SimpleCov.start

# Don't include spec files in the coverage report
SimpleCov.add_filter '/spec/'

# Require all lib/ files
Dir["#{File.dirname(__FILE__)}/../lib/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |c|
  c.mock_framework = :rspec
  # Ensure specs run in a random order to surface order depenencies
  c.order = 'random'
end
