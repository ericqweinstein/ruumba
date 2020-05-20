# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::Parser do
  let(:parser) { described_class.new }

  describe '#extract' do
    it 'extracts one line of Ruby code from an ERB template' do
      erb = "<%= puts 'Hello, world!' %>"

      expect(parser.extract(erb)).to eq("    puts 'Hello, world!'   ")
    end

    it 'extracts many lines of Ruby code from an ERB template' do
      erb = <<~RHTML
        <%= puts 'foo' %>
        <%= puts 'bar' %>
        <% baz %>
      RHTML

      expect(parser.extract(erb)).to eq("    puts 'foo'   \n    puts 'bar'   \n   baz   \n")
    end

    it 'extracts multiple interpolations per line' do
      erb = "<%= puts 'foo' %> then <% bar %>"

      expect(parser.extract(erb)).to eq("    puts 'foo' ;           bar   ")
    end

    it 'does extract single line ruby comments from an ERB template' do
      erb =
        <<~RHTML
          <% puts 'foo'
          # that puts is ruby code
          bar %>
        RHTML

      # rubocop:disable Layout/TrailingWhitespace
      parsed =
        <<~RUBY
             puts 'foo'
          # that puts is ruby code
          bar   
        RUBY
      # rubocop:enable Layout/TrailingWhitespace

      expect(parser.extract(erb)).to eq(parsed)
    end

    it 'does not extract ruby comments from interpolated code' do
      erb =
        <<~RHTML
          <%# this is a multiline comment
              interpolated in the ERB template
              it should be inside a comment %>
          <% puts 'foo' %>
        RHTML

      # rubocop:disable Layout/TrailingWhitespace
      parsed =
        <<~RUBY
            # this is a multiline comment
          #   interpolated in the ERB template
          #   it should be inside a comment   
             puts 'foo'   
        RUBY
      # rubocop:enable Layout/TrailingWhitespace

      expect(parser.extract(erb)).to eq(parsed)
    end

    it 'extracts and converts lines using <%== for the raw helper' do
      erb = <<~RHTML
        <span class="test" <%== 'style="display: none;"' if num.even? %>>
      RHTML

      expect(parser.extract(erb))
        .to eq("                    raw 'style=\"display: none;\"' if num.even?    \n")
    end

    it 'does not extract code from lines without ERB interpolation' do
      erb = "<h1>Dead or alive, you're coming with me.</h1>"

      expect(parser.extract(erb)).to eq(' ' * 46)
    end

    it 'extracts comments on the same line' do
      erb = '<% if (foo = bar) %><%# should always be truthy %>'

      expect(parser.extract(erb))
        .to eq('   if (foo = bar) ;    # should always be truthy   ')
    end

    context 'when configured with a region marker' do
      let(:parser) { described_class.new('mark') }

      it 'extracts comments on the same line' do
        erb = '<% if (foo = bar) %><%# should always be truthy %>'

        # rubocop:disable Layout/TrailingWhitespace
        ruby =
          <<~RUBY
              
            mark_0000000001
             if (foo = bar) 
            mark_0000000001
            ;    
            mark_0000000002
            # should always be truthy 
            mark_0000000002
              
          RUBY
          .chomp
        # rubocop:enable Layout/TrailingWhitespace

        expect(parser.extract(erb)).to eq(ruby)
      end
    end
  end
end
