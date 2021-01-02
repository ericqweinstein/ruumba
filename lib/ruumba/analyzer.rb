# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'
require 'digest'
require 'pathname'
require 'tmpdir'
require 'open3'
require 'English'

require 'ruumba/iterators'
require 'ruumba/correctors'
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

      iterator, corrector =
        if stdin?
          [Iterators::StdinIterator.new(File.expand_path(stdin_filename)), Correctors::StdinCorrector.new(digestor, parser)]
        else
          [Iterators::DirectoryIterator.new(files_or_dirs, temp_dir.to_s), Correctors::FileCorrector.new(digestor, parser)]
        end

      iterator.each do |file, contents|
        code, new_file_name = copy_erb_file(file, contents, temp_dir_path)

        if stdin?
          @stdin_contents = code
          @new_stdin_filename = new_file_name
        end
      end

      stdout, stderr, exit_code = RubocopRunner.new(arguments, pwd, temp_dir_path, @stdin_contents, !disable_rb_extension?).execute

      corrector.correct(stdout, stderr, file_mappings) if auto_correct?

      [[STDOUT, stdout], [STDERR, stderr]].each do |output_stream, output|
        next if output.nil? || output.empty?

        output_stream.puts(output)
      end

      exit_code
    end

    def extension
      '.rb' unless disable_rb_extension?
    end

    def auto_correct?
      options[:auto_correct]
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

    def auto_correct_marker
      return @auto_correct_marker if defined?(@auto_correct_marker)

      @auto_correct_marker = auto_correct? ? 'marker_' + SecureRandom.uuid.tr('-', '_') : nil
    end

    def parser
      @parser ||= Parser.new(auto_correct_marker)
    end

    def digestor
      @digestor ||= ->(contents) { Digest::SHA256.base64digest(contents) }
    end

    def file_mappings
      @file_mappings ||= {}
    end

    def copy_erb_file(file, contents, temp_dir)
      code = parser.extract(contents)
      new_file = temp_filename_for(file, temp_dir)

      if auto_correct?
        properties = []
        properties << new_file
        properties << digestor.call(code)

        properties <<
          if stdin?
            contents
          else
            -> { File.read(file) }
          end

        file_mappings[file] = properties
      end

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
