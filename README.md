Ruumba
======

[![Build Status](https://travis-ci.org/ericqweinstein/ruumba.svg?branch=master)](https://travis-ci.org/ericqweinstein/ruumba)

> .erb or .rb, you're coming with me.

> — RuboCop

## About
Ruumba is [RuboCop's](https://github.com/bbatsov/rubocop) sidekick, allowing you to lint your .erb Rubies as well as your regular-type ones.

## Dependencies
* Ruby 2.2.2+

## Installation
```bash
λ gem install ruumba
```

## Usage
Command line:

```bash
λ ruumba directory_of_erb_files/
```

Rake task:

```ruby
require 'ruumba/rake_task'

Ruumba::RakeTask.new(:ruumba) do |t|
  t.dir = %w(lib/views)
end
```

Then:

```bash
λ bundle exec rake ruumba
```

## Contributing
1. Branch (`git checkout -b fancy-new-feature`)
2. Commit (`git commit -m "Fanciness!"`)
3. Test (`bundle exec rake spec`)
4. Lint (`bundle exec rake rubocop`)
5. Push (`git push origin fancy-new-feature`)
6. Ye Olde Pulle Requeste
