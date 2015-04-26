# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::RakeTask do
  describe '#initialize' do
    it 'sets the name of the task when provided' do
      ruumba = Ruumba::RakeTask.new(:foo)
      expect(ruumba.name).to eq :foo
    end

    it 'defaults the task name to :ruumba when not provided' do
      ruumba = Ruumba::RakeTask.new
      expect(ruumba.name).to eq :ruumba
    end
  end
end
