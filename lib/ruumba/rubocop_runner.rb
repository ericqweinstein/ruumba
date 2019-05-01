# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'open3'

module Ruumba
  # Runs rubocop on the files in the given target_directory
  class RubocopRunner
    def initialize(arguments, current_directory, target_directory, stdin, rb_extension_enabled)
      @arguments = Array(arguments)
      @current_directory = current_directory
      @rb_extension_enabled = rb_extension_enabled
      @stdin = stdin
      @target_directory = target_directory
      @replacements = []

      # if adding the .rb extension is enabled, remove the extension again from
      # any output so it matches the actual files names we are linting
      @replacements << [/\.erb\.rb/, '.erb'] if rb_extension_enabled
    end

    # Executes rubocop, updating filenames in the output if needed.
    # @return the exit code of the rubocop process
    def execute
      args = ['rubocop'] + arguments
      todo = target_directory.join('.rubocop_todo.yml')

      results = Dir.chdir(target_directory) do
        replacements.unshift([/^#{Regexp.quote(Dir.pwd)}/, current_directory.to_s])

        stdout, stderr, status = Open3.capture3(*args, stdin_data: stdin)

        [munge_output(stdout), munge_output(stderr), status.exitstatus]
      end

      # copy the todo file back for the case where we've used --auto-gen-config
      FileUtils.cp(todo, current_directory) if todo.exist?

      results
    end

    private

    attr_reader :arguments, :current_directory, :rb_extension_enabled, :replacements, :stdin, :target_directory

    def munge_output(output)
      return output if output.nil? || output.empty?

      replacements.each do |pattern, replacement|
        output = output.gsub(pattern, replacement)
      end

      output
    end
  end
end
