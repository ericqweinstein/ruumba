# @author Eric Weinstein <eric.q.weinstein@gmail.com>
# More info at https://github.com/guard/guard#readme

guard :rspec, cmd: 'rspec --color --format d' do
  watch %r{^spec/.+_spec\.rb$}
  watch(%r{^lib/ruumba/(.+)\.rb$}) { |m| "spec/ruumba/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb') { 'spec' }
end
