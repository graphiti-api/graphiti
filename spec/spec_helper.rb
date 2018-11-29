$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }
require 'pry'

require 'active_model'
require 'graphiti_spec_helpers/rspec'
require 'graphiti'
# Avoiding loading classes before we're ready
Graphiti::Resource.autolink = false
require 'fixtures/poro'
Graphiti.setup!

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
end

# We test rails through appraisal
if ENV["APPRAISAL_INITIALIZED"]
  RSpec.configure do |config|
    # If not running tests for specific file, only run rails tests
    if config.instance_variable_get(:@files_or_directories_to_run) == ['spec']
      config.pattern = 'spec/integration/rails/**/*_spec.rb'
    end
  end

  # Avoid checking, because Rails is defined but we dont have autoloading
  Graphiti::Sideload.class_eval do
    def check!;end
  end

  require 'database_cleaner'
  require 'kaminari'
  require 'active_record'
  require 'graphiti/adapters/active_record'
  require 'rails_spec_helper'
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.establish_connection adapter: 'sqlite3',
    database: ':memory:'
  Dir[File.dirname(__FILE__) + "/fixtures/**/*.rb"].each {|f| require f }


  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  rspec.shared_context_metadata_behavior = :apply_to_host_groups


  config.include_context "pagination_context", include_shared: true

end
