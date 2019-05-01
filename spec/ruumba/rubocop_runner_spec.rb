# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::RubocopRunner do
  let(:runner) { described_class.new(arguments, current_directory, target, stdin, rb_extension_enabled) }
  let(:rb_extension_enabled) { false }
  let(:target) { Pathname.new(Dir.mktmpdir) }
  let(:arguments) { %w[--option val] }
  let(:status) { instance_double(Process::Status, exitstatus: exitstatus) }
  let(:stdout) { '' }
  let(:stderr) { '' }
  let(:munged_stdout) { '' }
  let(:munged_stderr) { '' }
  let(:stdin) { nil }
  let(:open3_results) { [stdout, stderr, status] }
  let(:results) { [stdout, stderr, exitstatus] }
  let!(:current_directory) { Pathname.new(ENV['PWD']) }
  let(:exitstatus) { 0 }

  describe '#execute' do
    before do
      expect(Open3).to receive(:capture3).with(*(['rubocop'] + arguments), stdin_data: stdin).and_return(open3_results)
    end

    after do
      FileUtils.remove_dir(target)
    end

    it 'returns the exitstatus from rubocop' do
      expect(runner.execute).to eq(results)
    end

    context 'when adding the .rb extension is enabled' do
      let(:results) { ['blah.js.erb', 'blubb.html.erb', exitstatus] }
      let(:rb_extension_enabled) { true }
      let(:stdout) { 'blah.js.erb.rb' }
      let(:stderr) { 'blubb.html.erb.rb' }

      it 'removes the rb extension from stdout and stderr' do
        expect(runner.execute).to eq(results)
      end
    end

    context 'when the output contains the temporary directory name' do
      let(:rb_extension_enabled) { true }
      let(:stdout) { target.join('blah.js.erb.rb').to_s }
      let(:stderr) { target.join('blubb.html.erb.rb').to_s }
      let(:results) { [current_directory.join('blah.js.erb').to_s, current_directory.join('blubb.html.erb').to_s, exitstatus] }

      it 'it replaces the target directory name with the current directory name' do
        expect(runner.execute).to eq(results)
      end
    end

    context 'when .rubocop_todo.yml exists in the target directory after executing' do
      before do
        FileUtils.touch(target.join('.rubocop_todo.yml'))
      end

      it 'copies .rubocop_todo.yml from the target directory to the current directory' do
        expect(FileUtils).to receive(:cp).with(target.join('.rubocop_todo.yml'), current_directory)
        expect(runner.execute).to eq(results)
      end
    end
  end
end
