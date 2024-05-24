source "https://rubygems.org"

# Specify your gem's dependencies in graphiti.gemspec
gemspec

github "rails/rails" do
  gem "activemodel"
  gem "rails"
end

gem "database_cleaner"
gem "graphiti-rails", "~> 0.4.0"
gem "rspec-rails"
gem "sqlite3"

group :test do
  gem "appraisal"
  gem "guard"
  gem "guard-rspec"
  gem "pry"
  gem "pry-byebug", platform: [:mri]
end
