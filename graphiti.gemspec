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
  spec.required_ruby_version = ">= 3.0"

  # TODO: remove once the 1.12 upgrade window has passed
  spec.post_install_message = <<~MSG
    Graphiti: relationship readable:/writable: guards are now enforced.

    Symbols, strings, and procs passed to a relationship's readable/writable
    guards were always interpreted as true and never actually called before this
    conditional relationship change. They are now evaluated per-request, where
    unreadable relationships are omitted from responses and includes, and unwritable
    relationships reject writes.

    To list every affected relationship in your app:

      bin/rails runner 'puts Graphiti.guarded_relationships'

    Audit these before deploying. Apps using schema.json will also see affected 
    relationships flagged as "became guarded" by the schema check.
  MSG

  spec.add_dependency "jsonapi-serializable", "~> 0.3.0"
  spec.add_dependency "jsonapi-renderer", "~> 0.2", ">= 0.2.2"
  spec.add_dependency "dry-types", ">= 0.15.0", "< 2.0"
  spec.add_dependency "graphiti_errors", "~> 1.1.0"
  spec.add_dependency "concurrent-ruby", ">= 1.2", "< 2.0"
  spec.add_dependency "activesupport", ">= 5.2"
  # Bundled (no longer default) as of Ruby 3.5; graphiti uses OpenStruct in lib/
  spec.add_dependency "ostruct", ">= 0.5"

  spec.add_development_dependency "faraday", "~> 0.15"
  spec.add_development_dependency "kaminari", "~> 0.17"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "standard", "~> 1.4.0"
  spec.add_development_dependency "activemodel", ">= 5.2"
  spec.add_development_dependency "graphiti_spec_helpers", "1.0.beta.4"
end
