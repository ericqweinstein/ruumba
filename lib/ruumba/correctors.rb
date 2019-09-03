# frozen_string_literal: true

module Ruumba
  # Responsible for extracted auto corrected code and updating the original ERBs files
  module Correctors
    # Module to help replace code
    module Replacer
      def handle_corrected_output(old_digest, new_contents, original_contents)
        new_digest = digestor.call(new_contents)

        return if old_digest == new_digest

        original_contents = original_contents.call if original_contents.respond_to?(:call)

        replaced_output = parser.replace(original_contents, new_contents)

        yield(replaced_output) if replaced_output
      end
    end

    # Corrector for when the checked file was passed through stdin.
    class StdinCorrector
      include Replacer

      def initialize(digestor, parser)
        @digestor = digestor
        @parser = parser
      end

      def correct(stdout, stderr, file_mappings)
        _, old_ruumba_digest, original_contents = *file_mappings.values.first

        [stdout, stderr].each do |output|
          next if output.nil? || output.empty?

          matches = output.scan(/\A(.*====================)?$(.*)\z/m)

          next if matches.empty?

          prefix, new_contents = *matches.first

          handle_corrected_output(old_ruumba_digest, new_contents, original_contents) do |corrected_output|
            output.clear
            output.concat("#{prefix}\n#{corrected_output}")
          end
        end
      end

      private

      attr_reader :digestor, :parser
    end

    # Corrector for when normal file checking
    class FileCorrector
      include Replacer

      def initialize(digestor, parser)
        @digestor = digestor
        @parser = parser
      end

      def correct(_stdout, _stderr, file_mappings)
        file_mappings.each do |original_file, (ruumba_file, old_ruumba_digest, original_contents)|
          new_contents = File.read(ruumba_file)

          handle_corrected_output(old_ruumba_digest, new_contents, original_contents) do |corrected_output|
            File.open(original_file, 'w+') do |file_handle|
              file_handle.write(corrected_output)
            end
          end
        end
      end

      private

      attr_reader :digestor, :parser
    end
  end
end
