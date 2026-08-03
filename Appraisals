# Graphiti's Rails integration ships in the gem itself as of 2.0, so there is
# one appraisal per Rails version rather than a with/without graphiti-rails pair.
#
# Rails 7.1 is the floor: 2.0 requires Ruby >= 3.2, and Rails 6.1 and 7.0 do not
# support it. Apps on older Rails stay on the graphiti 1.x branch.
#
# Every Rails requirement pins the minor ("~> 7.1.0", not "~> 7.1"). The looser
# form lets a newer minor satisfy it, which is how rails-7-1 and rails-8-0 ended
# up resolving to 7.2 and 8.1 - two appraisals apiece testing the same Rails and
# neither testing the version it was named for.
#
# sqlite3 pins follow what each Rails version's adapter demands at require time
# (activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb):
#   Rails 7.1       -> gem "sqlite3", "~> 1.4"   (2.x raises Gem::LoadError)
#   Rails 7.2       -> gem "sqlite3", ">= 1.4"
#   Rails 8.0 / 8.1 -> gem "sqlite3", ">= 2.1"
# "~> 1.4" rather than "~> 1.4.0" is deliberate: it resolves to 1.7.x, which
# still builds on modern Rubies, where 1.4.x no longer does.

appraise "rails-7-1" do
  gem "rails", "~> 7.1.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 1.4"
end

appraise "rails-7-2" do
  gem "rails", "~> 7.2.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-0" do
  gem "rails", "~> 8.0.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end

appraise "rails-8-1" do
  gem "rails", "~> 8.1.0"
  gem "rspec-rails"
  gem "responders"
  gem "sqlite3", "~> 2.1"
end
