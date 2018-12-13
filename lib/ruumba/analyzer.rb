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
          Iterators::StdinIterator.new(stdin_filename)
        else
          Iterators::DirectoryIterator.new(files_or_dirs)
        end

      iterator.each do |file, contents|
        copy_erb_file(file, contents, temp_dir_path)
      end

      RubocopRunner.new(arguments, pwd, temp_dir_path, !disable_rb_extension?).execute
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
      options[:arguments]
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

      n = temp_filename_for(file, temp_dir)
      FileUtils.mkdir_p(File.dirname(n))

      File.open(n, 'w+') do |tmp_file|
        tmp_file.write(code)
      end
    end

    def temp_filename_for(file, temp_dir)
      name = temp_dir.join(Pathname.new(file).relative_path_from(pwd))

      "#{name}#{extension}"
    end
  end
end
