# @author Eric Weinstein <eric.q.weinstein@gmail.com>
# @author Andrew Clemons <andrew.clemons@gmail.com>

require 'spec_helper'

describe Ruumba::Iterators::StdinIterator do
  let(:iterator) { described_class.new(filename) }
  let(:files) { iterator.to_a }
  let(:filename) { 'blah.erb' }
  let(:contents) { 'file contents' }

  describe '#each' do
    before do
      expect(STDIN).to receive(:read).and_return(contents)
    end

    it 'returns an iterator for a single file with the contents of stdin' do
      expect(files).to eq([[filename, contents]])
    end
  end
end

describe Ruumba::Iterators::DirectoryIterator do
  let(:iterator) { described_class.new(input_list) }
  let(:files) { iterator.to_a }

  describe '#each' do
    let(:target_dir) { Pathname.new(Dir.mktmpdir) }
    let(:file1) { target_dir.join('dir1', 'file1.erb') }
    let(:file2) { target_dir.join('dir2', 'file2.erb') }
    let(:file3) { target_dir.join('file3.erb') }
    let(:file4) { target_dir.join('file4.rb') }

    before do
      [file1, file2, file3, file4].each do |file|
        FileUtils.mkdir_p(File.dirname(file))

        File.open(file, 'w+') do |tmp_file|
          tmp_file.write("Contents of #{file}")
        end
      end
    end

    after do
      FileUtils.remove_dir(target_dir)
    end

    context 'when nil is passed as the directory' do
      let(:input_list) { nil }

      before do
        expect(File).to receive(:expand_path).with('.').and_return(target_dir.to_s)
      end

      it 'returns the erb files found' do
        expect(files.map(&:first).map(&:to_s)).to match_array([file1, file2, file3].map(&:to_s))
      end
    end

    context 'when a list of files and directories is passed' do
      let(:input_list) { [File.dirname(file1), File.dirname(file2), file3.to_s, file4.to_s] }

      it 'expands the directories and returns the erb files found' do
        expect(files.map(&:first).map(&:to_s)).to match_array([file1, file2, file3].map(&:to_s))
      end
    end
  end
end
