# frozen_string_literal: true

# @author Eric Weinstein <eric.q.weinstein@gmail.com>

module Ruumba
  # Responsible for extracting interpolated Ruby.
  class Parser
    # The regular expression to capture interpolated Ruby.
    ERB_REGEX = /<%[-=]?(.*?)-?%>/m

    # Extracts Ruby code from an ERB template.
    # @return [String] The extracted ruby code
    def extract(contents)
      file_text, matches = parse(contents)

      extracted_ruby = +''

      last_match = [0, 0]
      matches.each do |start_index, end_index|
        handled_region_before(start_index, last_match.last, file_text, extracted_ruby)

        extracted_ruby << extract_match(file_text, start_index, end_index)

        last_match = [start_index, end_index]
      end

      extracted_ruby << file_text[last_match.last..-1].gsub(/./, ' ')
      extracted_ruby.gsub!(/[^\S\r\n]+$/, '')

      extracted_ruby
    end

    private

    def parse(contents)
      # http://edgeguides.rubyonrails.org/active_support_core_extensions.html#output-safety
      # replace '<%==' with '<%= raw' to avoid generating invalid ruby code
      file_text = contents.gsub(/<%==/, '<%= raw')

      matching_regions = file_text.enum_for(:scan, ERB_REGEX)
                                  .map { Regexp.last_match.offset(1) }

      [file_text, matching_regions]
    end

    def handled_region_before(match_start, prev_end_index, file_text, extracted_ruby)
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
        # if this is a ruby comment inside, replace the whole match with spaces
        region.gsub!(/[^\r\n]/, ' ') if region[0] == '#'
      end
    end
  end
end
