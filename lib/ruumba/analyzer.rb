# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'
require 'pathname'
require 'tmpdir'
require 'open3'
require 'English'

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
      pwd = Pathname.new(ENV['PWD'])
      tmp = create_temp_dir

      if @options[:stdin]
        copy_erb_files(nil, tmp, pwd)
      else
        files_or_dirs = ['.'] if files_or_dirs.empty?
        fq_files_or_dirs = files_or_dirs.map { |file_or_dir| Pathname.new(File.expand_path(file_or_dir)) }
        copy_erb_files(fq_files_or_dirs, tmp, pwd)
      end

      run_rubocop(pwd, tmp)
    end

    private

    def create_temp_dir
      if @options[:tmp_folder]
        Pathname.new(File.expand_path(@options[:tmp_folder]))
      else
        Pathname.new(Dir.mktmpdir)
      end
    end

    def copy_erb_files(fq_files_or_dirs, tmp, pwd)
      extension = '.rb' unless @options[:disable_rb_extension]

      if @options[:stdin]
        copy_erb_file(@options[:stdin], STDIN.read, tmp, pwd, extension) if @options[:stdin].end_with?('.erb')
      else
        fq_files_or_dirs.each do |fq_file_or_dir|
          if fq_file_or_dir.file?
            copy_erb_file(fq_file_or_dir, File.read(fq_file_or_dir), tmp, pwd, extension) if fq_file_or_dir.to_s.end_with?('.erb')
          else
            Dir["#{fq_file_or_dir}/**/*.erb"].each do |f|
              copy_erb_file(f, File.read(f), tmp, pwd, extension)
            end
          end
        end
      end
    end

    def copy_erb_file(file, contents, tmp, pwd, extension)
      n = tmp + Pathname.new(file).relative_path_from(pwd)
      FileUtils.mkdir_p(File.dirname(n))

      File.open("#{n}#{extension}", 'w+') do |tmp_file|
        code = Parser.new.parse(contents)
        tmp_file.write(code)
      end
    end

    def run_rubocop(pwd, tmp)
      RubocopRunner.new(@options[:arguments], pwd, tmp, !@options[:disable_rb_extension]).execute
    end
  end
end
