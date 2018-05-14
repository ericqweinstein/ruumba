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

    # The regular expression used to detect blocks inside interpolated Ruby
    BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

    # Imaginary method so that <%= statement %> does not trigger Lint/Void warnings
    # Can be anything three chars long so as to keep the column numbers intact
    ERBOUT = 'erb'.freeze

    def initialize(opts = nil)
      @options = opts || {}
    end

    # Performs static analysis on the provided directory.
    # @param [Array<String>] dir The directories / files to analyze.
    def run(files_or_dirs = ARGV)
      files_or_dirs = ['.'] if files_or_dirs.empty?
      fq_files_or_dirs = files_or_dirs.map { |file_or_dir| Pathname.new(File.expand_path(file_or_dir)) }
      pwd = Pathname.new(ENV['PWD'])
      tmp = create_temp_dir

      copy_erb_files(fq_files_or_dirs, tmp, pwd)

      target = '.'
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
        handle_region_before(start_index, last_match.last, file_text, extracted_ruby)

        extracted_ruby << extract_match(file_text, start_index, end_index)

        last_match = [start_index, end_index]
      end

      extracted_ruby << file_text[last_match.last..-1].gsub(/./, ' ')

      # since we replace <%= with <%=erb when parsing the file, remove the
      # leading three spaces if possible so our column numbers line up
      extracted_ruby.gsub(/   #{ERBOUT}/, ERBOUT)
    end

    private

    def parse_file(filename)
      # replace <%= with a dummy method erb to avoid triggering the Lint/Void cop
      file_text = File.read(filename).gsub(/<%=/, "<%=#{ERBOUT}")

      # http://edgeguides.rubyonrails.org/active_support_core_extensions.html#output-safety
      # replace '<%==' with '<%= erb' (taking into account the replacment already done)
      # to avoid generating invalid ruby code
      file_text = file_text.gsub(/<%=erb=/, "<%= #{ERBOUT}")

      matching_regions = file_text.enum_for(:scan, ERB_REGEX)
                                  .map { Regexp.last_match.offset(1) }

      [file_text, matching_regions]
    end

    def handle_region_before(match_start, prev_end_index, file_text, extracted_ruby)
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

        region.sub!(/\A#{ERBOUT}/, ' ' * ERBOUT.length) if region.start_with?("#{ERBOUT} ") && region =~ BLOCK_EXPR
      end
    end

    def create_temp_dir
      if @options[:tmp_folder]
        Pathname.new(File.expand_path(@options[:tmp_folder]))
      else
        Pathname.new(Dir.mktmpdir)
      end
    end

    def copy_erb_files(fq_files_or_dirs, tmp, pwd)
      extension = '.rb' unless @options[:disable_rb_extension]

      fq_files_or_dirs.each do |fq_file_or_dir|
        if fq_file_or_dir.file?
          copy_erb_file(fq_file_or_dir, tmp, pwd, extension) if fq_file_or_dir.to_s.end_with?('.erb')
        else
          Dir["#{fq_file_or_dir}/**/*.erb"].each do |f|
            copy_erb_file(f, tmp, pwd, extension)
          end
        end
      end
    end

    def copy_erb_file(file, tmp, pwd, extension)
      n = tmp + Pathname.new(file).relative_path_from(pwd)
      FileUtils.mkdir_p(File.dirname(n))

      File.open("#{n}#{extension}", 'w+') do |tmp_file|
        code = extract(file)
        tmp_file.write(code)
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

        status.exitstatus.zero?
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
