# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'securerandom'

# Ruumba: RuboCop's sidekick.
module Ruumba
  # Generates analyzer objects that, when run, delegate
  # to RuboCop for linting (style, correctness, &c).
  class Analyzer
    # The regular expression to capture interpolated Ruby.
    ERB_REGEX = /<%=?(.*?)%>/

    # Performs static analysis on the provided directory.
    # @param [Array<String>] dir The directory to analyze.
    def run(dir = ARGV)
      fq_dir = File.expand_path dir.first
      suffix = SecureRandom.hex

      Dir["#{fq_dir}/**/*.erb"].each do |f|
        File.open("#{f}-#{suffix}.rb", 'w+') do |file|
          code = extract f
          file.write code
        end
      end

      system("rubocop #{fq_dir}")

      Dir.glob(Dir["#{fq_dir}/**/*-#{suffix}.rb"]).each { |f| File.delete(f) }
    end

    # Extracts Ruby code from an ERB template.
    # @param [String] filename The filename.
    # @return [String] The extracted Ruby code.
    def extract(filename)
      File.read(filename).scan(ERB_REGEX).map(&:last).map(&:strip).join("\n")
    end
  end
end
