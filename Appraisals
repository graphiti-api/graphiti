# NOTE: sqlite3 pins track what each Rails version's sqlite3 adapter demands at
# require time (activerecord/.../sqlite3_adapter.rb):
#   Rails 7.0        -> gem "sqlite3", "~> 1.4"   (strict; 2.x raises Gem::LoadError)
#   Rails 7.1 / 7.2  -> gem "sqlite3", ">= 1.4"
#   Rails 8.0 / 8.1  -> gem "sqlite3", ">= 2.1"
# Rails 7.0 is therefore capped at sqlite3 1.x. Note "~> 1.4" (not "~> 1.4.0")
# is deliberate: it resolves to 1.7.x, which still builds on modern Rubies,
# whereas pinning to 1.4.x specifically does not.

appraise "rails-7-0" do
  gem "rails", "~> 7.0.0"
  gem "rspec-rails"
  gem "sqlite3", "~> 1.4"
end

appraise "rails-7-0-graphiti-rails" do
  gem "rails", "~> 7.0.0"
  gem "rspec-rails"
  gem "sqlite3", "~> 1.4"
  gem "graphiti-rails", "~> 0.4.0"
end

appraise "rails-7-1" do
  gem "rails", "~> 7.1"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-7-1-graphiti-rails" do
  gem "rails", "~> 7.1"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
  gem "graphiti-rails", "~> 0.4.0"
end

appraise "rails-7-2" do
  gem "rails", "~> 7.2"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-7-2-graphiti-rails" do
  gem "rails", "~> 7.2"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
  gem "graphiti-rails", "~> 0.4.0"
end

appraise "rails-8-0" do
  gem "rails", "~> 8.0"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-0-graphiti-rails" do
  gem "rails", "~> 8.0"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
  gem "graphiti-rails", "~> 0.4.0"
end

appraise "rails-8-1" do
  gem "rails", "~> 8.1"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-1-graphiti-rails" do
  gem "rails", "~> 8.1"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.1"
  gem "graphiti-rails", "~> 0.4.0"
end
