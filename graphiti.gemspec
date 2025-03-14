lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "graphiti/version"

Gem::Specification.new do |spec|
  spec.name = "graphiti"
  spec.version = Graphiti::VERSION
  spec.authors = ["Lee Richmond"]
  spec.email = ["richmolj@gmail.com"]

  spec.summary = "Easily build jsonapi.org-compatible APIs"
  spec.homepage = "https://github.com/graphiti-api/graphiti"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "jsonapi-serializable", "~> 0.3.0"
  spec.add_dependency "jsonapi-renderer", "~> 0.2", ">= 0.2.2"
  spec.add_dependency "dry-types", ">= 0.15.0", "< 2.0"
  spec.add_dependency "graphiti_errors", "~> 1.1.0"
  spec.add_dependency "concurrent-ruby", ">= 1.2", "< 2.0"
  spec.add_dependency "activesupport", ">= 5.2"

  spec.add_development_dependency "faraday", "~> 0.15"
  spec.add_development_dependency "kaminari", "~> 0.17"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "standard", "~> 1.4.0"
  spec.add_development_dependency "activemodel", ">= 5.2"
  spec.add_development_dependency "graphiti_spec_helpers", "1.0.beta.4"
end
