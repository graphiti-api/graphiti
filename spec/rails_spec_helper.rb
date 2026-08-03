# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.
require "bundler/setup" unless defined?(Bundler)
require "rails"
require "action_controller"

require "graphiti/rails"

module BasicRailsApp
  module_function

  # Make a very basic app, without creating the whole directory structure.
  # Is faster and simpler than generating a Rails app in a temp directory
  def generate
    @app = Class.new(Rails::Application) {
      config.eager_load = false
      config.session_store :cookie_store, key: "_myapp_session"
      config.active_support.deprecation = :log
      config.root = File.dirname(__FILE__)
      config.log_level = :info
      # Set a logger to avoid creating the log directory automatically
      config.logger = Logger.new(ENV["DEBUG"] ? $stdout : nil)
      config.logger.level = Logger::DEBUG
      Rails.application.routes.default_url_options = {host: "example.com"}

      Rails.application.config.hosts << "www.example.com"
    }
    @app.respond_to?(:secrets) && @app.secrets.secret_key_base = "3b7cd727ee24e8444053437c36cc66c4"

    yield @app if block_given?
    @app.initialize!
  end
end

::Rails.application = BasicRailsApp.generate

class ApplicationController < ActionController::Base
  include Rails.application.routes.url_helpers
  include Graphiti::Rails::Controller
end

require "rspec/rails"

RSpec.configure do |config|
  config.include UniversalControllerSpecHelper

  if defined?(RescueRegistry)
    config.after do
      # Normally this happens in a standard Rails middleware, but most of our tests bypass middleware
      RescueRegistry.context = nil
    end
  end
end
