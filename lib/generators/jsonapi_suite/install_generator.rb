module JsonapiSuite
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    # spec helpers to test?
    # gem 'jsonapi-rails', '~> 0.1'
    # require 'jsonapi_compliable/adapters/active_record'
    desc "This generator boostraps jsonapi-suite with an initialize and controller mixin"
    def create_initializer
      to = File.join('config/initializers', 'jsonapi.rb')
      template('initializer.rb.erb', to)

      to = File.join('config/initializers', "strong_resources.rb")
      template('strong_resources.rb.erb', to)

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::API\n" do <<-'RUBY'
  include JsonapiSuite::ControllerMixin
RUBY
end

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::Base\n" do <<-'RUBY'
  include JsonapiSuite::ControllerMixin
RUBY
end
    end
  end
end
