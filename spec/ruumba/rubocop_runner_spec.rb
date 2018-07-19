# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::RubocopRunner do
  let(:runner) { described_class.new(arguments, current_directory, target, rb_extension_enabled) }
  let(:rb_extension_enabled) { false }
  let(:target) { Pathname.new(Dir.mktmpdir) }
  let(:arguments) { %w[--option val] }
  let(:status) { double(Process::Status) }
  let(:stdout) { '' }
  let(:stderr) { '' }
  let(:results) { [stdout, stderr, status] }
  let!(:current_directory) { Pathname.new(ENV['PWD']) }
  let(:exitstatus) { 0 }

  describe '#execute' do
    before do
      expect(Open3).to receive(:capture3).with(*(['rubocop'] + arguments)).and_return(results)
      expect(status).to receive(:exitstatus).and_return(exitstatus)
    end

    it 'returns the exitstatus from rubocop' do
      expect(runner.execute).to eq(exitstatus)
    end

    context 'when adding the .rb extension is enabled' do
      let(:rb_extension_enabled) { true }
      let(:stdout) { 'blah.js.erb.rb' }
      let(:stderr) { 'blubb.html.erb.rb' }

      it 'removes the rb extension from stdout and stderr' do
        expect(STDOUT).to receive(:puts).with('blah.js.erb')
        expect(STDERR).to receive(:puts).with('blubb.html.erb')

        expect(runner.execute).to eq(exitstatus)
      end
    end

    context 'when the output contains the temporary directory name' do
      let(:rb_extension_enabled) { true }
      let(:stdout) { target.join('blah.js.erb.rb').to_s }
      let(:stderr) { target.join('blubb.html.erb.rb').to_s }

      it 'it replaces the target directory name with the current directory name' do
        expect(STDOUT).to receive(:puts).with(current_directory.join('blah.js.erb').to_s)
        expect(STDERR).to receive(:puts).with(current_directory.join('blubb.html.erb').to_s)

        expect(runner.execute).to eq(exitstatus)
      end
    end

    context 'when .rubocop_todo.yml exists in the target directory after executing' do
      before do
        FileUtils.touch(target.join('.rubocop_todo.yml'))
      end

      it 'copies .rubocop_todo.yml from the target directory to the current directory' do
        expect(FileUtils).to receive(:cp).with(target.join('.rubocop_todo.yml'), current_directory)
        expect(runner.execute).to eq(exitstatus)
      end
    end
  end
end
