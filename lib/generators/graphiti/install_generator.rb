require_relative "generator_mixin"
require_relative "locale_generator"

module Graphiti
  class InstallGenerator < ::Rails::Generators::Base
    include GeneratorMixin

    source_root File.expand_path("templates", __dir__)

    class_option :"omit-comments",
      type: :boolean,
      default: false,
      aliases: ["-c"],
      desc: "Generate without documentation comments"

    desc "This generator boostraps graphiti"
    def install
      to = File.join("app/resources", "application_resource.rb")
      template("application_resource.rb.erb", to)

      invoke(Graphiti::LocaleGenerator, [], options)

      inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::API\n" do
        app_controller_code
      end

      inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do
        app_controller_code
      end

      # Thor aborts the whole generator when this file is missing.
      if defined?(RSpec) && File.exist?(File.join(destination_root, "spec/rails_helper.rb"))
        inject_into_file "spec/rails_helper.rb", after: /RSpec.configure.+^end$/m do
          <<~RUBY

            require "graphiti/spec_helpers/rspec"

            RSpec.configure do |config|
              config.include Graphiti::SpecHelpers::RSpec
            end

            Graphiti::SpecHelpers::RSpec.schema!
          RUBY
        end
      end

      insert_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
        namespace_scope
      end
    end

    private

    def omit_comments?
      @options["omit-comments"]
    end

    # The resource generator re-finds this scope by its format default.
    def namespace_scope
      lines = ["  scope path: \"#{api_namespace}\", defaults: {format: :jsonapi} do\n"]
      lines << "    mount VandalUi::Engine, at: '/vandal'\n" if defined?(VandalUi)
      lines << "    # your routes go here\n"
      lines << "  end\n"
      lines.join
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
