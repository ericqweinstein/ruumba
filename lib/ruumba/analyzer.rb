# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'
require 'pathname'
require 'tmpdir'

# Ruumba: RuboCop's sidekick.
module Ruumba
  # Generates analyzer objects that, when run, delegate
  # to RuboCop for linting (style, correctness, &c).
  class Analyzer
    # The regular expression to capture interpolated Ruby.
    ERB_REGEX = /<%=?(.*?)%>/m

    def initialize(opts = nil)
      @options = opts || {}
    end

    # Performs static analysis on the provided directory.
    # @param [Array<String>] dir The directory to analyze.
    def run(dir = ARGV)
      fq_dir = Pathname.new(File.expand_path(dir.first))
      pwd = Pathname.new ENV['PWD']
      target = fq_dir.relative_path_from(pwd)

      if @options[:tmp_folder]
        tmp = Pathname.new(File.expand_path(@options[:tmp_folder]))
        FileUtils.rm_rf(tmp)
      else
        tmp = Pathname.new(Dir::mktmpdir)
      end

      Dir["#{fq_dir}/**/*.erb"].each do |f|
        n = tmp + Pathname.new(f).relative_path_from(pwd)
        FileUtils.mkdir_p(File.dirname(n))

        File.open("#{n}.rb", 'w+') do |file|
          code = extract f
          file.write code
        end
      end

      if @options && @options[:arguments]
        args = @options[:arguments].join(' ')
      else
        args = ''
      end

      system("cd #{tmp} && rubocop #{args} #{target}")

      todo = tmp + '.rubocop_todo.yml'
      FileUtils.cp(todo, ENV['PWD']) if File.exists?(todo)

      if !@options[:tmp_folder]
        FileUtils.rm_rf(tmp)
      end
    end

    # Extracts Ruby code from an ERB template.
    # @param [String] filename The filename.
    # @return [String] The extracted Ruby code.
    def extract(filename)
      File.read(filename).scan(ERB_REGEX).map(&:last).map(&:strip).join("\n")
    end
  end
end
