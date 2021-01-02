# @author Eric Weinstein <eric.q.weinstein@gmail.com>

# Ruumba: RuboCop's sidekick.
module Ruumba
  # Generates analyzer objects that, when run, delegate
  # to RuboCop for linting (style, correctness, &c).
  module Iterators
    # Iterator which returns the file passed in via stdin
    class StdinIterator
      include Enumerable

      def initialize(file)
        @file = file
      end

      def each(&block)
        [[file, STDIN.read]].each(&block)
      end

      private

      attr_reader :file
    end

    # Iterator which returns matching files from the given directory or file list
    class DirectoryIterator
      include Enumerable

      def initialize(files_or_dirs, temp_dir)
        @files_or_dirs = files_or_dirs
        @temp_dir = temp_dir
      end

      def each(&block)
        files.map do |file|
          [file, File.read(file)]
        end.each(&block)
      end

      private

      attr_reader :files_or_dirs, :temp_dir

      def files
        full_list.flat_map do |file_or_dir|
          if file_or_dir.file?
            file_or_dir if file_or_dir.to_s.end_with?('.erb')
          else
            Dir[File.join(file_or_dir, '**/*.erb')].map do |file|
              Pathname.new(file) unless file.start_with?(temp_dir)
            end
          end
        end.compact
      end

      def full_list
        if files_or_dirs.nil? || files_or_dirs.empty?
          [expand_path('.')]
        else
          files_or_dirs.map do |file_or_dir|
            expand_path(file_or_dir)
          end
        end
      end

      def expand_path(file_or_dir)
        Pathname.new(File.expand_path(file_or_dir))
      end
    end
  end
end
