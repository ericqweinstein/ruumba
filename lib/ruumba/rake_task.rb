# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'rake'
require 'rake/tasklib'

module Ruumba
  # Provides a custom Rake task.
  class RakeTask < Rake::TaskLib
    attr_accessor :name, :dir, :options

    # Sets up the custom Rake task.
    # @param [Array<String>] args Arguments to the Rake task.
    # @yield If called with a block, we'll call it to ensure
    # additional options are included (_e.g._ dir).
    def initialize(*args, &block)
      @name = args.shift || :ruumba
      @dir  = []
      @options = nil

      desc 'Run RuboCop on ERB files'
      task(name, *args) do |_, task_args|
        yield(*[self, task_args].slice(0, block.arity)) if block
        run
      end
    end

    private

    # Executes the custom Rake task.
    # @private
    def run
      # Like RuboCop itself, we'll lazy load so the task
      # doesn't substantially impact Rakefile load time.
      require 'ruumba'

      analyzer = Ruumba::Analyzer.new(@options)
      puts 'Running Ruumba...'

      exit(analyzer.run(@dir))
    end
  end
end
