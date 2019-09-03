# @author Andrew Clemons <andrew.clemons@gmail.com>

require 'spec_helper'
require 'tempfile'

describe Ruumba::Correctors::Replacer do
  class TestReplacer
    include Ruumba::Correctors::Replacer

    attr_accessor :digestor, :parser

    def initialize(digestor, parser)
      @digestor = digestor
      @parser = parser
    end
  end

  describe '#handle_corrected_input' do
    subject(:replacer) { TestReplacer.new(digestor, parser) }
    let(:digestor) { double }
    let(:parser) { double }
    let(:old_digest) { 1 }
    let(:original_contents) { 'some code' }

    before do
      expect(digestor).to receive(:call).with(new_contents).and_return(new_digest)
    end

    context 'when the contents have not changed' do
      let(:new_digest) { old_digest }
      let(:new_contents) { original_contents }

      it 'returns nil' do
        expect(replacer.handle_corrected_output(old_digest, new_contents, original_contents)).to be nil
      end
    end

    context 'when the contents have changed' do
      let(:new_digest) { 2 }
      let(:new_contents) { 'some new code' }

      shared_examples_for 'corrected output' do
        before do
          expect(parser).to receive(:replace).with(original_contents_value, new_contents).and_return(replaced_output)
        end

        context 'when the output is successfully replaced' do
          let(:replaced_output) { 'replaced code' }
          let(:block) do
            lambda do |yielded_output|
              expect(yielded_output).to eq(replaced_output)

              yielded_output
            end
          end

          it 'yields the result' do
            expect(replacer.handle_corrected_output(old_digest, new_contents, original_contents, &block)).to eq(replaced_output)
          end
        end

        context 'when the output was not successfully replaced' do
          let(:replaced_output) { nil }

          it 'returns nil' do
            expect(replacer.handle_corrected_output(old_digest, new_contents, original_contents)).to be nil
          end
        end
      end

      context 'when the original contents are directly passed' do
        let(:original_contents_value) { original_contents }

        it_behaves_like 'corrected output'
      end

      context 'when the original contents are passed as a proc' do
        let(:original_contents) { -> { 'some code' } }
        let(:original_contents_value) { 'some code' }

        it_behaves_like 'corrected output'
      end
    end
  end
end

describe Ruumba::Correctors::StdinCorrector do
  let(:digestor) { double }
  let(:parser) { double }
  let(:old_digest) { 1 }
  let(:original_contents) { 'some code' }
  let(:new_contents) { 'new code' }
  let(:file_mappings) { { 'ignored' => ['ignored2', old_digest, original_contents] } }
  let(:stderr) { '' }
  let(:stdout_base) do
    <<~STDOUT
      Inspecting 1 file
      W

      Offenses:

      app/views/file.rb:17:31: C: [Corrected] Layout/SpaceAroundEqualsInParameterDefault: Surrounding space missing in default value assignment.
        def blah(thing='other')
                      ^

      1 file inspected, 1 offense detected, 1 offense corrected
      ====================
      #{new_contents}
    STDOUT
  end
  let(:stdout) { stdout_base.dup }
  let(:stdout_replaced) { "#{stdout_base.chomp} - fixed" }
  subject(:corrector) { described_class.new(digestor, parser) }

  describe '#correct' do
    it 'replaces the output contents with the corrected output' do
      expect(corrector).to receive(:handle_corrected_output).with(old_digest, "\n#{new_contents}\n", original_contents) { |&block| block.call("#{new_contents} - fixed") }

      corrector.correct(stdout, stderr, file_mappings)

      expect(stdout).to eq(stdout_replaced)
    end

    context 'when outputting in JSON format' do
      let(:stdout_base) do
        <<~STDOUT
          {"metadata":{"rubocop_version":"0.74.0","ruby_engine":"ruby","ruby_version":"2.6.3","ruby_patchlevel":"62","ruby_platform":"x86_64-linux"},"files":[{"path":"app/views/file.rb","offenses":[{"severity":"convention","message":"Surrounding space missing in default value assignment.","cop_name":"Layout/SpaceAroundEqualsInParameterDefault","corrected":true,"location":{"start_line":17,"start_column":31,"last_line":17,"last_column":31,"length":1,"line":17,"column":31}}]}],"summary":{"offense_count":1,"target_file_count":1,"inspected_file_count":1}}====================
          #{new_contents}
        STDOUT
      end
      it 'replaces the output contents with the corrected output' do
        expect(corrector).to receive(:handle_corrected_output).with(old_digest, "\n#{new_contents}\n", original_contents) { |&block| block.call("#{new_contents} - fixed") }

        corrector.correct(stdout, stderr, file_mappings)

        expect(stdout).to eq(stdout_replaced)
      end
    end
  end
end

describe Ruumba::Correctors::FileCorrector do
  let(:digestor) { double }
  let(:parser) { double }
  let(:old_digest) { 1 }
  let(:original_contents) { 'some code' }
  let(:new_contents) { 'new code' }
  let(:file_mappings) { { original_file => [ruumba_file, old_digest, original_contents] } }
  let(:original_file) { Tempfile.new }
  let(:ruumba_file) { Tempfile.new }
  subject(:corrector) { described_class.new(digestor, parser) }

  describe '#correct' do
    before do
      File.open(ruumba_file, 'w') { |file| file.puts new_contents }
      File.open(original_file, 'w') { |file| file.puts original_contents }
    end

    it 'replaces the file contents with the corrected output' do
      expect(corrector).to receive(:handle_corrected_output).with(old_digest, "#{new_contents}\n", original_contents) { |&block| block.call(new_contents) }

      corrector.correct(nil, nil, file_mappings)

      expect(File.read(original_file)).to eq(new_contents)
    end
  end
end
