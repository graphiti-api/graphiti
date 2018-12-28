$:.unshift File.dirname(__FILE__)
require 'generator_mixin'

module Graphiti
  class InstallGenerator < ::Rails::Generators::Base
    include GeneratorMixin

    source_root File.expand_path('../templates', __FILE__)

    class_option :'omit-comments',
      type: :boolean,
      default: false,
      aliases: ['-c'],
      desc: 'Generate without documentation comments'

    desc "This generator boostraps graphiti"
    def install
      to = File.join('app/resources', "application_resource.rb")
      template('application_resource.rb.erb', to)

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::API\n" do
        app_controller_code
      end

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::Base\n" do
        app_controller_code
      end

      inject_into_file 'config/application.rb', after: "Rails::Application\n" do
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

      inject_into_file 'spec/rails_helper.rb', after: /RSpec.configure.+^end$/m do
"\n\nGraphitiSpecHelpers::RSpec.schema!"
      end

      insert_into_file "config/routes.rb", :after => "Rails.application.routes.draw do\n" do
        <<-STR
  scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
    # your routes go here
  end
        STR
      end
    end

    private

    def omit_comments?
      @options['omit-comments']
    end

    def app_controller_code
      str = ""
      str << "  include Graphiti::Rails\n"
      str << "  include Graphiti::Responders\n"
      str << "\n"
      str << "  register_exception Graphiti::Errors::RecordNotFound,\n"
      str << "    status: 404\n"
      str << "\n"
      str << "  rescue_from Exception do |e|\n"
      str << "    handle_exception(e)\n"
      str << "  end\n"
      str
    end
  end
end
