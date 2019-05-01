# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'open3'
require 'English'

require 'ruumba/iterators'
require 'ruumba/parser'
require 'ruumba/rubocop_runner'

# Ruumba: RuboCop's sidekick.
module Ruumba
  # Generates analyzer objects that, when run, delegate
  # to RuboCop for linting (style, correctness, &c).
  class Analyzer
    def initialize(opts = nil)
      @options = opts || {}
    end

    # Performs static analysis on the provided directory.
    # @param [Array<String>] dir The directories / files to analyze.
    def run(files_or_dirs = ARGV)
      if options[:tmp_folder]
        analyze(File.expand_path(options[:tmp_folder]), files_or_dirs)
      else
        Dir.mktmpdir do |dir|
          analyze(dir, files_or_dirs)
        end
      end
    end

    private

    attr_reader :options

    def analyze(temp_dir, files_or_dirs)
      temp_dir_path = Pathname.new(temp_dir)

      iterator =
        if stdin?
          Iterators::StdinIterator.new(File.expand_path(stdin_filename))
        else
          Iterators::DirectoryIterator.new(files_or_dirs)
        end

      iterator.each do |file, contents|
        code, new_file_name = copy_erb_file(file, contents, temp_dir_path)

        if stdin?
          @stdin_contents = code
          @new_stdin_filename = new_file_name
        end
      end

      RubocopRunner.new(arguments, pwd, temp_dir_path, @stdin_contents, !disable_rb_extension?).execute
    end

    def extension
      '.rb' unless disable_rb_extension?
    end

    def stdin?
      stdin_filename
    end

    def stdin_filename
      options[:stdin]
    end

    def arguments
      if stdin?
        options[:arguments] + ['--stdin', @new_stdin_filename]
      else
        options[:arguments]
      end
    end

    def disable_rb_extension?
      options[:disable_rb_extension]
    end

    def pwd
      @pwd ||= Pathname.new(ENV['PWD'])
    end

    def parser
      @parser ||= Parser.new
    end

    def copy_erb_file(file, contents, temp_dir)
      code = parser.extract(contents)
      new_file = temp_filename_for(file, temp_dir)

      unless stdin?
        FileUtils.mkdir_p(File.dirname(new_file))

        File.open(new_file, 'w+') do |tmp_file|
          tmp_file.write(code)
        end
      end

      [code, new_file]
    end

    def temp_filename_for(file, temp_dir)
      name = temp_dir.join(Pathname.new(file).relative_path_from(pwd))

      "#{name}#{extension}"
    end
  end
end
