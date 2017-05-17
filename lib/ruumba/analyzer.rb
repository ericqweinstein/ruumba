# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'
require 'pathname'

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
      if @options[:tmp_folder]
        tmp = Pathname.new(File.expand_path(@options[:tmp_folder]))
        FileUtils.rm_rf(tmp)
      else
        tmp = Pathname.new("#{fq_dir}/ruumba_tmp_#{SecureRandom.hex[0..3]}/")
      end

      Dir["#{fq_dir}/**/*.erb"].each do |f|
        n = tmp + Pathname.new(f).relative_path_from(fq_dir)
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

      if !@options[:tmp_folder]
        FileUtils.rm_rf(tmp)
      end

      system("rubocop #{args} #{tmp}")
    end

    # Extracts Ruby code from an ERB template.
    # @param [String] filename The filename.
    # @return [String] The extracted Ruby code.
    def extract(filename)
      File.read(filename).scan(ERB_REGEX).map(&:last).map(&:strip).join("\n")
    end
  end
end
