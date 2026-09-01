source "https://rubygems.org"

# Specify your gem's dependencies in graphiti.gemspec
gemspec

# Until rescue_registry 1.1 ships with the fiber storage fix.
gem "rescue_registry", "~> 1.1"

group :test do
  gem "database_cleaner"
  gem "pry"
  gem "pry-byebug", platform: [:mri]
  gem "appraisal"
  gem "guard"
  gem "guard-rspec"
end
