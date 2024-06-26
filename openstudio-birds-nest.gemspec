
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio/birds_nest/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-birds-nest'
  spec.version       = OpenStudio::BirdsNest::VERSION
  spec.authors       = ['Joshua Kneifel', 'Luke Donmoyer']
  spec.email         = ['joshua.kneifel@nist.gov']

  spec.summary       = 'library and measures for OpenStudio for interacting with the Birds Nest API'
  spec.description   = 'library and measures for OpenStudio for interacting with the Birds Nest API'
  spec.homepage      = 'https://openstudio.net'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.7.0'

  spec.add_development_dependency 'bundler', '>= 2.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 1.15.0'

  spec.add_dependency 'openstudio-extension', '~> 0.6.1'
  spec.add_dependency 'openstudio-standards', '~> 0.4.0'
end
