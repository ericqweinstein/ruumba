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
    # The regular expression to capture interpolated Ruby.
    ERB_REGEX = /<%[-=]?(.*?)-?%>/m

    def initialize(opts = nil)
      @options = opts || {}
    end

    # Performs static analysis on the provided directory.
    # @param [Array<String>] dir The directory to analyze.
    def run(dir = ARGV)
      fq_dir = Pathname.new(File.expand_path(dir.first))
      pwd = Pathname.new ENV['PWD']
      target = fq_dir.relative_path_from(pwd)
      tmp = create_temp_dir

      copy_erb_files(fq_dir, tmp, pwd)
      run_rubocop(target, tmp)
    end

    # Extracts Ruby code from an ERB template.
    # @param [String] filename The filename.
    # @return [String] The extracted Ruby code.
    def extract(filename)
      file_text, matches = parse_file(filename)

      extracted_ruby = ''

      last_match = [0, 0]
      matches.each do |start_index, end_index|
        handled_region_before(start_index, last_match.last, file_text, extracted_ruby)

        extracted_ruby << extract_match(file_text, start_index, end_index)

        last_match = [start_index, end_index]
      end

      extracted_ruby << file_text[last_match.last..-1].gsub(/./, ' ')
    end

    private

    def parse_file(filename)
      # http://edgeguides.rubyonrails.org/active_support_core_extensions.html#output-safety
      # replace '<%==' with '<%= raw' to avoid generating invalid ruby code
      file_text = File.read(filename).gsub(/<%==/, '<%= raw')

      matching_regions = file_text.enum_for(:scan, ERB_REGEX)
                                  .map { Regexp.last_match.offset(1) }

      [file_text, matching_regions]
    end

    def handled_region_before(match_start, prev_end_index,
                              file_text, extracted_ruby)
      return unless match_start > prev_end_index

      region_before = file_text[prev_end_index..match_start - 1]

      extracted_ruby << region_before.gsub(/./, ' ')

      # if the last match was on the same line, we need to use a semicolon to
      # separate statements
      extracted_ruby[prev_end_index] = ';' if needs_stmt_delimiter?(prev_end_index, region_before)
    end

    def needs_stmt_delimiter?(last_match, region_before)
      last_match.positive? && region_before.index("\n").nil?
    end

    def extract_match(file_text, start_index, end_index)
      file_text[start_index...end_index].tap do |region|
        region.gsub!(/./, ' ') if region[0] == '#'
      end
    end

    def create_temp_dir
      if @options[:tmp_folder]
        Pathname.new(File.expand_path(@options[:tmp_folder]))
      else
        Pathname.new(Dir.mktmpdir)
      end
    end

    def copy_erb_files(fq_dir, tmp, pwd)
      extension = '.rb' unless @options[:disable_rb_extension]

      Dir["#{fq_dir}/**/*.erb"].each do |f|
        n = tmp + Pathname.new(f).relative_path_from(pwd)
        FileUtils.mkdir_p(File.dirname(n))

        File.open("#{n}#{extension}", 'w+') do |file|
          code = extract f
          file.write code
        end
      end
    end

    def run_rubocop(target, tmp)
      args = ['rubocop'] + (@options[:arguments] || []) + [target.to_s]
      todo = tmp + '.rubocop_todo.yml'

      pwd = ENV['PWD']

      replacements = []

      replacements << [/^#{Regexp.quote(tmp.to_s)}/, pwd]

      unless @options[:disable_rb_extension]
        replacements << [/\.erb\.rb/, '.erb']
      end

      result = Dir.chdir(tmp) do
        stdout, stderr, status = Open3.capture3(*args)

        munge_output(stdout, stderr, replacements)

        status.success?
      end

      FileUtils.cp(todo, pwd) if File.exist?(todo)
      FileUtils.rm_rf(tmp) unless @options[:tmp_folder]

      result
    end

    def munge_output(stdout, stderr, replacements)
      [[STDOUT, stdout], [STDERR, stderr]].each do |output_stream, output|
        next if output.nil? || output.empty?

        replacements.each do |pattern, replacement|
          output.gsub!(pattern, replacement)
        end

        output_stream.puts(output)
      end
    end
  end
end
