# Graphiti's Rails integration ships in the gem itself as of 2.0, so there is
# one appraisal per Rails version rather than a with/without graphiti-rails pair.
appraise "rails-6" do
  gem "rails", "~> 6.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 1.4.0"
end

appraise "rails-7" do
  gem "rails", "~> 7.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 1.4.0"
end

appraise "rails-7-1" do
  gem "rails", "~> 7.1"
  gem "rspec-rails"
  gem "responders"
  # activerecord 7.1's sqlite3 adapter requires sqlite3 ~> 1.4; 7.2 is the first
  # version that accepts 2.x.
  gem "sqlite3", "~> 1.4.0"
end

appraise "rails-7-2" do
  gem "rails", "~> 7.2"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-0" do
  gem "rails", "~> 8.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-1" do
  gem "rails", "~> 8.1"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end
