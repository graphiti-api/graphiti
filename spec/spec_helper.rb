$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].sort.each { |f| require f }
require "pry"

require "logger"
require "active_model"
require "graphiti_spec_helpers/rspec"
require "graphiti"
# Avoiding loading classes before we're ready
Graphiti::Resource.autolink = false
require "fixtures/poro"
Graphiti.setup!

# Optional dep for cross-api requests
require "faraday"
require "base64"

RSpec.configure do |config|
  config.include GraphitiSpecHelpers::RSpec
  config.include GraphitiSpecHelpers::Sugar

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

  # Avoid checking, because Rails is defined but we dont have autoloading
  Graphiti::Sideload.class_eval do
    def check!
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

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
  unless defined?(::ActionDispatch::Journey)
    require "uri"
    # NOTE: `decode_www_form_component` isn't an ideal default for production,
    # because it varies slightly compared to typical uri parameterization,
    # but it will allow tests to pass in non-rails contexts.
    Graphiti.config.uri_decoder = URI.method(:decode_www_form_component)
  end
end
