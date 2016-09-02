# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi_compliable/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi_compliable"
  spec.version       = JsonapiCompliable::VERSION
  spec.authors       = ["Venkata Pasupuleti"]
  spec.email         = ["spasupuleti4@bloomberg.net"]

  spec.summary       = %q{JSON Compliable serializer for action controller}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails"
  spec.add_dependency "jsonapi"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "kaminari"
  spec.add_development_dependency "active_model_serializers"
  spec.add_development_dependency "nested_attribute_reassignable"
  spec.add_development_dependency "jsonapi_spec_helpers"
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "factory_girl"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "database_cleaner"
end
