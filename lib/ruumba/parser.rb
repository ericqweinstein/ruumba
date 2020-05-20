# frozen_string_literal: true

# @author Eric Weinstein <eric.q.weinstein@gmail.com>

module Ruumba
  # Responsible for extracting interpolated Ruby.
  class Parser
    # The regular expression to capture interpolated Ruby.
    ERB_REGEX = /<%[-=]?(.*?)-?%>/m.freeze

    def initialize(region_start_marker = nil)
      @region_start_marker = region_start_marker
    end

    # Extracts Ruby code from an ERB template.
    # @return [String] The extracted ruby code
    def extract(contents)
      file_text, matches = parse(contents)

      extracted_ruby = +''

      last_match = [0, 0]
      matches.each_with_index do |(start_index, end_index), index|
        handle_region_before(start_index, last_match.last, file_text, extracted_ruby)

        match_marker = "#{region_start_marker}_#{format('%010d', index + 1)}" if region_start_marker
        extracted_ruby << extract_match(file_text, start_index, end_index, match_marker)

        last_match = [start_index, end_index]
      end

      extracted_ruby << file_text[last_match.last..-1].gsub(/./, ' ')

      # if we replaced <%== with <%= raw, try to shift the columns back to the
      # left so they match the original again
      extracted_ruby.gsub!(/   raw/, 'raw')

      extracted_ruby
    end

    def replace(old_contents, new_contents)
      file_text, matches = parse(old_contents)

      auto_corrected_erb = +''

      last_match = [0, 0]
      matches.each_with_index do |(start_index, end_index), index|
        match_start = start_index
        prev_end_index = last_match.last

        if start_index > prev_end_index
          region_before = file_text[prev_end_index..match_start - 1]

          auto_corrected_erb << region_before
        end

        suffix = format('%010d', index + 1)
        match_marker = "#{region_start_marker}_#{suffix}"

        match_without_markers = new_contents[/\n#{match_marker}$\n(.*)\n#{match_marker}\n/m, 1]

        # auto-correct is still experimental and can cause invalid ruby to be generated when extracting ruby from ERBs
        return nil unless match_without_markers

        auto_corrected_erb << match_without_markers

        last_match = [start_index, end_index]
      end

      auto_corrected_erb << file_text[last_match.last..-1]

      auto_corrected_erb
    end

    private

    attr_reader :region_start_marker

    def parse(contents)
      # http://edgeguides.rubyonrails.org/active_support_core_extensions.html#output-safety
      # replace '<%==' with '<%= raw' to avoid generating invalid ruby code
      file_text = contents.gsub(/<%==/, '<%= raw')

      matching_regions = file_text.enum_for(:scan, ERB_REGEX)
                                  .map { Regexp.last_match.offset(1) }

      [file_text, matching_regions]
    end

    def handle_region_before(match_start, prev_end_index, file_text, extracted_ruby)
      return unless match_start > prev_end_index

      last_position = extracted_ruby.length

      region_before = file_text[prev_end_index..match_start - 1]

      region_before.gsub!(/./, ' ')

      # if the last match was on the same line, we need to use a semicolon to
      # separate statements
      extracted_ruby[last_position] = ';' if needs_stmt_delimiter?(prev_end_index, region_before)

      extracted_ruby << region_before
    end

    def needs_stmt_delimiter?(last_match, region_before)
      last_match.positive? && region_before.index("\n").nil?
    end

    def extract_match(file_text, start_index, end_index, match_marker)
      file_text[start_index...end_index].tap do |region|
        # if there is a ruby comment inside, replace the beginning of each line
        # with the '#' so we end up with valid ruby

        if region[0] == '#'
          region.gsub!(/^ /, '#')
          region.gsub!(/^(?!#)/, '#')
        end

        if match_marker
          region.prepend("\n", match_marker, "\n")
          region.concat("\n", match_marker, "\n")
        end
      end
    end
  end
end
