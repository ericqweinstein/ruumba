Gem::Specification.new do |g|
  g.name          = 'ruumba'
  g.version       = File.read('VERSION')
  g.authors       = ['Eric Weinstein', 'Jan Biniok', 'Yvan Barthélemy']
  g.date          = '2018-04-16'
  g.description   = 'RuboCop linting for ERB templates.'
  g.email         = 'eric.q.weinstein@gmail.com'
  g.files         = Dir.glob('{lib}/**/*') + %w(README.md Rakefile)
  g.homepage      = 'https://github.com/ericqweinstein/ruumba'
  g.require_paths = %w(lib)
  g.summary       = 'Allows users to lint Ruby code in ERB templates the same way they lint source code (using RuboCop).'
  g.licenses      = %w(MIT)
  g.executables   << 'ruumba'
  g.add_dependency 'rubocop'
end
