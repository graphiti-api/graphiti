# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.
require 'bundler/setup' unless defined?(Bundler)
require 'rails'
require 'action_controller'
require 'graphiti/rails'
require 'graphiti/railtie'

module BasicRailsApp
  module_function

  # Make a very basic app, without creating the whole directory structure.
  # Is faster and simpler than generating a Rails app in a temp directory
  def generate
    @app = Class.new(Rails::Application) do
      config.eager_load = false
      config.session_store :cookie_store, key: '_myapp_session'
      config.active_support.deprecation = :log
      config.root = File.dirname(__FILE__)
      config.log_level = :info
      # Set a fake logger to avoid creating the log directory automatically
      fake_logger = Logger.new(nil)
      config.logger = fake_logger
      Rails.application.routes.default_url_options = { host: 'example.com' }

      # fix railties 5.2.0 issue with secret_key_base
      # https://github.com/rails/rails/commit/7419a4f9 should take care of it
      # in the future.
      if Rails::VERSION::MAJOR == 5
        if Rails::VERSION::MINOR >= 2
          def secret_key_base
            '3b7cd727ee24e8444053437c36cc66c4'
          end
        end
      end
    end
    @app.respond_to?(:secrets) && @app.secrets.secret_key_base = '3b7cd727ee24e8444053437c36cc66c4'

    yield @app if block_given?
    @app.initialize!
  end
end

::Rails.application = BasicRailsApp.generate

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  include Graphiti::Rails
end

require 'rspec/rails'

RSpec.configure do |config|
  config.include UniversalControllerSpecHelper
end
