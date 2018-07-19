# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::Analyzer do
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
end
