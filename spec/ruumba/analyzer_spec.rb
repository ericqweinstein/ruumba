# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::Analyzer do # rubocop:disable Metrics/BlockLength
  let(:analyzer) { Ruumba::Analyzer.new }

  describe '#run' do
    it 'analyzes the provided ERB files' do
      status = double
      expect(status).to receive(:exitstatus).and_return(0)

      results = ['', '', status]
      expect(Open3).to receive(:capture3).and_return(results)

      expect(analyzer.run(['foo'])).to eq(true)
    end
  end

  describe '#extract' do # rubocop:disable Metrics/BlockLength
    it 'extracts one line of Ruby code from an ERB template' do
      one = "<%= puts 'Hello, world!' %>"
      allow(File).to receive(:read).with('one.erb') { one }

      expect(analyzer.extract('one.erb')).to eq("    puts 'Hello, world!'   ")
    end

    it 'extracts many lines of Ruby code from an ERB template' do
      many = "<%= puts 'foo' %>\n<%= puts 'bar' %>\n<% baz %>"
      allow(File).to receive(:read).with('many.erb') { many }

      expect(analyzer.extract('many.erb')).to eq("    puts 'foo'   \n    puts 'bar'   \n   baz   ")
    end

    it 'extracts multiple interpolations per line' do
      multi = "<%= puts 'foo' %> then <% bar %>"
      allow(File).to receive(:read).with('multi.erb') { multi }

      expect(analyzer.extract('multi.erb')).to eq("    puts 'foo' ;          bar   ")
    end

    it 'does extract single line ruby comments from an ERB template' do
      comment = <<~RHTML
        <% puts 'foo'
        # that puts is ruby code
        bar %>
      RHTML

      allow(File).to receive(:read).with('comment.erb') { comment }

      # rubocop:disable Layout/TrailingWhitespace
      parsed = <<~RUBY
           puts 'foo'
        # that puts is ruby code
        bar   
      RUBY
      # rubocop:enable Layout/TrailingWhitespace

      expect(analyzer.extract('comment.erb')).to eq(parsed)
    end

    it 'does not extract ruby comments from interpolated code' do
      comment = <<~RHTML
        <%# this is a multiline comment
            interpolated in the ERB template
            it should resolve to nothing %>
      RHTML

      allow(File).to receive(:read).with('comment.erb') { comment }

      expect(analyzer.extract('comment.erb')).to eq(comment.gsub(/./, ' '))
    end

    it 'extracts and converts lines using <%== for the raw helper' do
      comment = <<~RHTML
        <span class="test" <%== 'style="display: none;"' if num.even? %>>
      RHTML

      allow(File).to receive(:read).with('comment.erb') { comment }

      expect(analyzer.extract('comment.erb'))
        .to eq("#{' ' * 23}raw 'style=\"display: none;\"' if num.even?    \n")
    end

    it 'does not extract code from lines without ERB interpolation' do
      none = "<h1>Dead or alive, you're coming with me.</h1>"
      allow(File).to receive(:read).with('none.erb') { none }

      expect(analyzer.extract('none.erb')).to eq(' ' * none.length)
    end
  end
end
