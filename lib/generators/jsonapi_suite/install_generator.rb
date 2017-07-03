module JsonapiSuite
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    class_option :'omit-comments',
      type: :boolean,
      default: false,
      aliases: ['-c'],
      desc: 'Generate without documentation comments'

    desc "This generator boostraps jsonapi-suite with an initialize and controller mixin"
    def create_initializer
      to = File.join('config/initializers', 'jsonapi.rb')
      template('initializer.rb.erb', to)

      to = File.join('config/initializers', "strong_resources.rb")
      template('strong_resources.rb.erb', to)

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::API\n" do
        app_controller_code
      end

      inject_into_file 'app/controllers/application_controller.rb', after: "class ApplicationController < ActionController::Base\n" do
        app_controller_code
      end
    end

    private

    def app_controller_code
      str = ""
      unless omit_comments?
        str << "  # Bootstrap jsonapi_suite with relevant modules\n"
      end
      str << "  include JsonapiSuite::ControllerMixin\n\n"
      unless omit_comments?
        str << "  # Catch all exceptions and render a JSONAPI-compliable error payload\n"
        str << "  # For additional documentation, see https://jsonapi-suite.github.io/jsonapi_errorable\n"
      end
      str << "  rescue_from Exception do |e|\n"
      str << "    handle_exception(e)\n"
      str << "  end\n"
      str
    end

    def omit_comments?
      !!@options['omit-comments']
    end
  end
end
