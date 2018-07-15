$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }
require 'pry'

require 'active_model'
require 'jsonapi_spec_helpers/rspec'
require 'jsonapi_compliable'
require 'fixtures/poro'

RSpec.configure do |config|
  config.include JsonapiSpecHelpers::RSpec
  config.include JsonapiSpecHelpers::Sugar

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
end

# We test rails through appraisal
if ENV["APPRAISAL_INITIALIZED"]
  RSpec.configure do |config|
    # If not running tests for specific file, only run rails tests
    if config.instance_variable_get(:@files_or_directories_to_run) == ['spec']
      config.pattern = 'spec/integration/rails/**/*_spec.rb'
    end
  end

  require 'database_cleaner'
  require 'kaminari'
  require 'active_record'
  require 'jsonapi_compliable/adapters/active_record'
  require 'rails_spec_helper'
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.establish_connection adapter: 'sqlite3',
    database: ':memory:'
  Dir[File.dirname(__FILE__) + "/fixtures/**/*.rb"].each {|f| require f }
end
