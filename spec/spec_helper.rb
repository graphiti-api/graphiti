$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_record'

# Easier require coming soon https://github.com/kaminari/kaminari/issues/518
require 'kaminari/config'
require 'kaminari/helpers/action_view_extension'
require 'kaminari/helpers/paginator'
require 'kaminari/models/page_scope_methods'
require 'kaminari/models/configuration_methods'
require 'kaminari/hooks'
Kaminari::Hooks.init

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f }
require 'database_cleaner'

require 'pry'
require 'jsonapi_compliable'
require 'jsonapi_compliable/adapters/null'
require 'jsonapi_compliable/adapters/active_record'

RSpec.configure do |config|
  config.after do
    PORO::DB.clear
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

Dir[File.dirname(__FILE__) + "/fixtures/**/*.rb"].each {|f| require f }
