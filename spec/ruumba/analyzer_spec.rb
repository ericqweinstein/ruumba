# @author Eric Weinstein <eric.q.weinstein@gmail.com>

require 'spec_helper'

describe Ruumba::Analyzer do
  subject(:analysis) { analyzer.run(file_list) }
  let(:analyzer) { described_class.new(options) }
  let(:current_directory) { Pathname.new(ENV['PWD']) }
  let(:rubocop_runner) { double(Ruumba::RubocopRunner) }
  let(:parser) { double(Ruumba::Parser) }
  let(:result) { 1 }
  let(:rubocop_arguments) { %w[--lint-only] }
  let(:disable_rb_extension) { false }
  let(:file_list) { ['app', 'lib', 'spec/thing_spec.rb'] }
  let(:options) do
    {
      arguments: rubocop_arguments,
      disable_rb_extension: disable_rb_extension,
      tmp_folder: temp_folder_option
    }
  end

  describe '#run' do
    before do
      expect(Ruumba::RubocopRunner).to receive(:new).with(
        rubocop_arguments, Pathname.new(ENV['PWD']), temp_dir, !disable_rb_extension
      ).and_return(rubocop_runner)
      expect(Ruumba::Parser).to receive(:new).and_return(parser)
    end

    context 'when passing in the filename via stdin' do
      let(:stdin_filename) { 'file1.erb' }
      let(:file_and_content) do
        [
          [current_directory.join('file1.erb'), 'contents1']
        ]
      end

      before do
        options[:stdin] = stdin_filename
        expect(Ruumba::Iterators::StdinIterator).to receive(:new).with(stdin_filename).and_return(file_and_content)
        expect(parser).to receive(:extract).with('contents1').and_return('code1')
      end

      shared_examples_for 'linting a single file' do
        it 'copies the file, adding the .rb extension and runs rubocop' do
          expect(File).to receive(:open).with(temp_dir.join('file1.erb.rb').to_s, 'w+')

          expect(rubocop_runner).to receive(:execute).and_return(result)

          expect(analysis).to eq(result)
        end

        context 'when the rb extension is disabled' do
          let(:disable_rb_extension) { true }

          it 'copies the file and runs rubocop' do
            expect(File).to receive(:open).with(temp_dir.join('file1.erb').to_s, 'w+')

            expect(rubocop_runner).to receive(:execute).and_return(result)

            expect(analysis).to eq(result)
          end
        end
      end

      context 'when no temporary directory is configured' do
        let(:temp_folder_option) { nil }
        let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

        before do
          expect(Dir).to receive(:mktmpdir).and_return(temp_dir)
        end

        it_behaves_like 'linting a single file'
      end

      context 'when a temporary directory is configured' do
        let(:temp_folder_option) { temp_dir.to_s }
        let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

        it_behaves_like 'linting a single file'
      end
    end

    context 'when file names are passed as arguments' do
      let(:files_and_contents) do
        [
          [current_directory.join('file1.erb'), 'contents1'],
          [current_directory.join('file2.erb'), 'contents2']
        ]
      end

      before do
        expect(Ruumba::Iterators::DirectoryIterator).to receive(:new).with(file_list).and_return(files_and_contents)
        expect(parser).to receive(:extract).with('contents1').and_return('code1')
        expect(parser).to receive(:extract).with('contents2').and_return('code2')
      end

      shared_examples_for 'linting a list of files' do
        it 'copies the files, adding the .rb extension and runs rubocop' do
          expect(File).to receive(:open).with(temp_dir.join('file1.erb.rb').to_s, 'w+')
          expect(File).to receive(:open).with(temp_dir.join('file2.erb.rb').to_s, 'w+')

          expect(rubocop_runner).to receive(:execute).and_return(result)

          expect(analysis).to eq(result)
        end

        context 'when the rb extension is disabled' do
          let(:disable_rb_extension) { true }

          it 'copies the files and runs rubocop' do
            expect(File).to receive(:open).with(temp_dir.join('file1.erb').to_s, 'w+')
            expect(File).to receive(:open).with(temp_dir.join('file2.erb').to_s, 'w+')

            expect(rubocop_runner).to receive(:execute).and_return(result)

            expect(analysis).to eq(result)
          end
        end
      end

      context 'when no temporary directory is configured' do
        let(:temp_folder_option) { nil }
        let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

        before do
          expect(Dir).to receive(:mktmpdir).and_return(temp_dir)
        end

        it_behaves_like 'linting a list of files'
      end

      context 'when a temporary directory is configured' do
        let(:temp_folder_option) { temp_dir.to_s }
        let(:temp_dir) { Pathname.new(Dir.mktmpdir) }

        it_behaves_like 'linting a list of files'
      end
    end
  end
end
