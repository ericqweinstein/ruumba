# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'pathname'
require 'securerandom'
require 'tmpdir'

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
      File.read(filename).scan(ERB_REGEX).map(&:last)
          .reject { |line| line[0] == '#' }
          .map(&:strip).join("\n")
    end

    private

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

    def autofix!(target, tmp)
      src_dir = Pathname.new(File.expand_path(target))

      Dir.foreach(tmp) do |f|
        # Match the extracted code from the tmp directory
        # to its original file in the source directory in
        # order to find-and-replace for --auto-correct.
        src = f.split('.').tap(&:pop).join '.'

        if File.extname(src) == '.erb' && File.exist?("#{src_dir}/#{src}")
          # Walk through the extracted .erb.rb file and write
          # its contents into the interpolation areas of the
          # original .erb file.
          code       = File.readlines("#{tmp}/#{f}")
          noncode    = File.readlines("#{src_dir}/#{src}")
                           .reject { |l| l =~ ERB_REGEX }
          to_correct = File.readlines("#{src_dir}/#{src}")
          out        = []

          to_correct.each do |line|
            # @TODO: This is pretty hacky. (EQW 30 Aug 2017)
            out << if line.match?(/<%/)
                     "  <% #{code.shift.rstrip} %>\n"
                   elsif /<%=/
                     "  <%= #{code.shift.rstrip} %>\n"
                   else
                     noncode.shift
                   end
          end

          File.open("#{src_dir}/#{src}", 'w') do |contents|
            contents << out.join
          end
        end
      end
    end

    def run_rubocop(target, tmp)
      args = (@options[:arguments] || []).join(' ')
      todo = tmp + '.rubocop_todo.yml'

      system("cd #{tmp} && rubocop #{args} #{target}").tap do
        FileUtils.cp(todo, ENV['PWD']) if File.exist?(todo)
        autofix!(target, tmp) if @options[:arguments]&.include? '--auto-correct'
        FileUtils.rm_rf(tmp) unless @options[:tmp_folder]
      end
    end
  end
end
