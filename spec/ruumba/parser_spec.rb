# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::Parser do
  let(:analyzer) { described_class.new }

  describe '#extract' do
    it 'extracts one line of Ruby code from an ERB template' do
      erb = "<%= puts 'Hello, world!' %>"

      expect(analyzer.extract(erb)).to eq("    puts 'Hello, world!'")
    end

    it 'extracts many lines of Ruby code from an ERB template' do
      erb = <<~RHTML
        <%= puts 'foo' %>
        <%= puts 'bar' %>
        <% baz %>"
      RHTML

      expect(analyzer.extract(erb)).to eq("    puts 'foo'\n    puts 'bar'\n   baz\n")
    end

    it 'extracts multiple interpolations per line' do
      erb = "<%= puts 'foo' %> then <% bar %>"

      expect(analyzer.extract(erb)).to eq("    puts 'foo' ;          bar")
    end

    it 'does extract single line ruby comments from an ERB template' do
      erb =
        <<~RHTML
          <% puts 'foo'
          # that puts is ruby code
          bar %>
        RHTML

      parsed =
        <<~RUBY
             puts 'foo'
          # that puts is ruby code
          bar
        RUBY

      expect(analyzer.extract(erb)).to eq(parsed)
    end

    it 'does not extract ruby comments from interpolated code' do
      erb =
        <<~RHTML
          <%# this is a multiline comment
              interpolated in the ERB template
              it should be inside a comment %>
          <% puts 'foo' %>
        RHTML

      parsed =
        <<~RUBY
            # this is a multiline comment
          #   interpolated in the ERB template
          #   it should be inside a comment
             puts 'foo'
        RUBY

      expect(analyzer.extract(erb)).to eq(parsed)
    end

    it 'extracts and converts lines using <%== for the raw helper' do
      erb = <<~RHTML
        <span class="test" <%== 'style="display: none;"' if num.even? %>>
      RHTML

      expect(analyzer.extract(erb))
        .to eq("                    raw 'style=\"display: none;\"' if num.even?\n")
    end

    it 'does not extract code from lines without ERB interpolation' do
      erb = "<h1>Dead or alive, you're coming with me.</h1>"

      expect(analyzer.extract(erb)).to eq('')
    end
  end
end
