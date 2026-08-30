$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].sort.each { |f| require f }
require "pry"

require "logger"
require "active_model"
require "graphiti/spec_helpers/rspec"
require "graphiti"
# Avoiding loading classes before we're ready
Graphiti::Resource.relationship_links = false
require "fixtures/poro"
Graphiti.setup!

# Optional dep for cross-api requests
require "faraday"
require "base64"

RSpec.configure do |config|
  config.include Graphiti::SpecHelpers::RSpec

  config.after do
    PORO::DB.clear
  end

  config.before(:all, type: :controller) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each, type: :controller) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Every anonymous Class.new(SomeResource) registers itself in the global
  # Graphiti.resources via the inherited hook, and nothing ever removes it.
  # Graphiti.setup! walks that list and re-applies sideloads, so without this
  # an example calling setup! reaches back into every throwaway resource
  # earlier examples defined - which makes results depend on spec order.
  config.around do |example|
    registered = Graphiti.resources.dup
    setup_was = Graphiti.setup?
    example.run
  ensure
    Graphiti.resources.replace(registered)
    Graphiti.instance_variable_set(:@setup, setup_was)
  end

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = File.expand_path(".rspec-examples", __dir__)
end

# We test rails through appraisal
if ENV["APPRAISAL_INITIALIZED"]
  RSpec.configure do |config|
    # If not running tests for specific file, only run rails tests
    if config.instance_variable_get(:@files_or_directories_to_run) == ["spec"]
      config.pattern = "spec/integration/rails/**/*_spec.rb"
    end
  end

  require "database_cleaner"
  require "kaminari"
  require "active_record"
  require "graphiti/adapters/active_record"
  require "rails_spec_helper"
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.establish_connection adapter: "sqlite3",
    database: ":memory:"
  Dir[File.dirname(__FILE__) + "/fixtures/**/*.rb"].sort.each { |f| require f }
end
