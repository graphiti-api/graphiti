# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi_suite/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi_suite"
  spec.version       = JsonapiSuite::VERSION
  spec.authors       = ["Lee Richmond"]
  spec.email         = ["lrichmond1@bloomberg.net"]

  spec.summary       = %q{Collection of gems for jsonapi.org-compatible APIs}
  spec.description   = %q{Handles automatic swagger documentation, error handling, serialization, etc}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails', ['>= 4.1', '< 6']
  spec.add_dependency 'strong_resources', '~> 0.1'
  spec.add_dependency 'jsonapi_compliable', '~> 0.3'
  spec.add_dependency 'jsonapi_errorable', '~> 0.1'
  spec.add_dependency 'jsonapi_spec_helpers', '~> 0.2'
  spec.add_dependency 'jsonapi_ams_extensions', '~> 0.1'
  spec.add_dependency 'jsonapi_swagger_helpers', '~> 0.1'
  spec.add_dependency 'active_model_serializers', '~> 0.10.x'
  spec.add_dependency 'nested_attribute_reassignable', '~> 0.6'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
