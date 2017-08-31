Ruumba
======

[![Build Status](https://travis-ci.org/ericqweinstein/ruumba.svg?branch=master)](https://travis-ci.org/ericqweinstein/ruumba)

> .erb or .rb, you're coming with me.

> — RuboCop

## About
Ruumba is [RuboCop's](https://github.com/bbatsov/rubocop) sidekick, allowing you to lint your .erb Rubies as well as your regular-type ones.

## Dependencies
* Ruby 2.4.1+ (older Rubies may work, but are not explicitly supported)

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

## Experimental Features
You can auto-correct infractions that RuboCop itself knows how to auto-correct:

```bash
λ ruumba --auto-correct directory_of_erb_files/
```

**Please note** that this feature is experimental and may not do what you want; be sure only to modify files that are under source control, and please feel free to submit bug reports and/or pull requests regarding any unintended or confusing behavior.

## Fix Paths and Non-Applicable Cops
By default, RuboCop only scans `.rb` files and so does Ruumba. If you want paths to reflect original paths, you can add a `.ruumba.yml` config file
with the following contents:

```yaml
AllCops:
  Include:
    - '**/*.erb'
```

You can then disable `.rb` extension auto-append and use your config file:

```bash
λ ruumba -D -e app/views -c .ruumba.yml
```

Since Ruumba rewrites new files from `.erb` files contents, some formatting cops cannot apply; you can disable them in your Ruumba file:

```yaml
Style/FrozenStringLiteralComment:
  Enabled: false
Layout/AlignHash:
  Enabled: false
Layout/AlignParameters:
  Enabled: false
Layout/IndentationWidth:
  Enabled: false
Layout/TrailingBlankLines:
  Enabled: false
```

You can use `ruumba -D` to look for other cops if this list is missing some.

You might want to include your existing RuboCop config file by appending this in front of your Ruumba config:

```yaml
inherit_from: .rubocop.yml
```


## Contributing
1. Branch (`git checkout -b fancy-new-feature`)
2. Commit (`git commit -m "Fanciness!"`)
3. Test (`bundle exec rake spec`)
4. Lint (`bundle exec rake rubocop`)
5. Push (`git push origin fancy-new-feature`)
6. Ye Olde Pulle Requeste
