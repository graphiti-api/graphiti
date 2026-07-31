require_relative "generator_mixin"

module Graphiti
  class InstallGenerator < ::Rails::Generators::Base
    include GeneratorMixin

    source_root File.expand_path("templates", __dir__)

    class_option :'omit-comments',
      type: :boolean,
      default: false,
      aliases: ["-c"],
      desc: "Generate without documentation comments"

    desc "This generator boostraps graphiti"
    def install
      to = File.join("app/resources", "application_resource.rb")
      template("application_resource.rb.erb", to)

      inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::API\n" do
        app_controller_code
      end

      inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do
        app_controller_code
      end

      inject_into_file "config/application.rb", after: "Rails::Application\n" do
        <<-'RUBY'
    # In order for Graphiti to generate links, you need to set the routes host.
    # When not explicitly set, via the HOST env var, this will fall back to
    # the rails server settings.
    # Rails::Server is not defined in console or rake tasks, so this will only
    # use those defaults when they are available.
    routes.default_url_options[:host] = ENV.fetch('HOST') do
      if defined?(Rails::Server)
        argv_options = Rails::Server::Options.new.parse!(ARGV)
        "http://#{argv_options[:Host]}:#{argv_options[:Port]}"
      end
    end
        RUBY
      end

      if defined?(RSpec)
        inject_into_file "spec/rails_helper.rb", after: /RSpec.configure.+^end$/m do
          <<~RUBY

            require "graphiti/spec_helpers/rspec"

            RSpec.configure do |config|
              config.include Graphiti::SpecHelpers::RSpec
              config.include Graphiti::SpecHelpers::Sugar
            end

            Graphiti::SpecHelpers::RSpec.schema!
          RUBY
        end
      end

      insert_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
        if defined?(VandalUi)
          <<-STR
  scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
    mount VandalUi::Engine, at: '/vandal'
    # your routes go here
  end
          STR
        else
          <<-STR
  scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
    # your routes go here
  end
          STR
        end
      end
    end

    private

    def omit_comments?
      @options["omit-comments"]
    end

    def app_controller_code
      str = +"  include Graphiti::Rails::Controller\n"
      if defined?(::Responders)
        str << "  include Graphiti::Rails::Responders\n"
      end
      str
    end
  end
end
