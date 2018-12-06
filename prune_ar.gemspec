# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prune_ar/version'

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = 'prune_ar'
  spec.version       = PruneAr::VERSION
  spec.authors       = ['Anirban Mukhopadhyay']
  spec.email         = ['amukhopadhyay@contently.com']

  spec.summary       = 'Prunes database tables using ActiveRecord belongs_to relations.'
  spec.description   = %w[
    Given an initial set of records to delete prune_ar deletes all other records (accessible via
    ActiveRecord) that are now orphaned due to a belongs_to relation which is now non-existent.
    This allows you to safely delete records that you want to delete without creating orphaned
    records in another table (& without violating foreign key constraints if you use them). This
    can be used to prune a production database (given deletion criteria for top level parent-less
    independent entities) for use in a development environment without compromising customer data.
  ].join(' ')
  spec.homepage = 'https://github.com/contently/prune_ar'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'pry', '~> 0.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rubocop', '~> 0.61'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
end
