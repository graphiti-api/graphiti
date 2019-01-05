# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'graphiti/version'

Gem::Specification.new do |spec|
  spec.name          = "graphiti"
  spec.version       = Graphiti::VERSION
  spec.authors       = ["Lee Richmond"]
  spec.email         = ["richmolj@gmail.com"]

  spec.summary       = %q{Easily build jsonapi.org-compatible APIs}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '~> 2.3'

  # Pinning this version until backwards-incompatibility is addressed
  spec.add_dependency 'jsonapi-serializable', '~> 0.3.0'
  spec.add_dependency 'dry-types', '~> 0.13'
  spec.add_dependency 'graphiti_errors', '~> 1.0.beta.1'
  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'activesupport', ['>= 4.1', '< 6']

  spec.add_development_dependency "activerecord", ['>= 4.1', '< 6']
  spec.add_development_dependency "kaminari", '~> 0.17'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "activemodel", ['>= 4.1', '< 6']
  spec.add_development_dependency "graphiti_spec_helpers", '1.0.beta.4'
end
