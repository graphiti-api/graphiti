module Jsonapi
  class ResourceGenerator < ::Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    class_option :'omit-comments',
      type: :boolean,
      default: false,
      aliases: ['--omit-comments', '-c'],
      desc: 'Generate without documentation comments'
    class_option :'omit-controller',
      type: :boolean,
      default: false,
      aliases: ['--omit-controller'],
      desc: 'Generate without controller'
    class_option :'omit-serializer',
      type: :boolean,
      default: false,
      aliases: ['--omit-serializer', '-s'],
      desc: 'Generate without serializer'
    class_option :'omit-payload',
      type: :boolean,
      default: false,
      aliases: ['--omit-payload', '-p'],
      desc: 'Generate without spec payload'
    class_option :'omit-strong-resource',
      type: :boolean,
      default: false,
      aliases: ['--omit-strong-resource', '-r'],
      desc: 'Generate without strong resource'
    class_option :'omit-route',
      type: :boolean,
      default: false,
      aliases: ['--omit-route'],
      desc: 'Generate without specs'
    class_option :'omit-tests',
      type: :boolean,
      default: false,
      aliases: ['--omit-tests', '-t'],
      desc: 'Generate without specs'

    desc "This generator creates a resource file at app/resources, as well as corresponding controller/specs/route/etc"
    def copy_resource_file
      unless model_klass
        raise "You must define a #{class_name} model before generating the corresponding resource."
      end

      generate_controller unless omit_controller?
      generate_serializer unless omit_serializer?
      generate_application_resource unless application_resource_defined?
      generate_spec_payload unless omit_spec_payload?
      generate_strong_resource unless omit_strong_resource?
      generate_route unless omit_route?
      generate_tests unless omit_tests?
      generate_resource
    end

    private

    def omit_comments?
      @options['omit-comments']
    end

    def generate_controller
      to = File.join('app/controllers', class_path, "#{file_name.pluralize}_controller.rb")
      template('controller.rb.erb', to)
    end

    def omit_controller?
      @options['omit-controller']
    end

    def generate_serializer
      to = File.join('app/serializers', class_path, "serializable_#{file_name}.rb")
      template('serializer.rb.erb', to)
    end

    def omit_serializer?
      @options['omit-serializer']
    end

    def generate_application_resource
      to = File.join('app/resources', class_path, "application_resource.rb")
      template('application_resource.rb.erb', to)
    end

    def application_resource_defined?
      'ApplicationResource'.safe_constantize.present?
    end

    def generate_spec_payload
      to = File.join('spec/payloads', class_path, "#{file_name}.rb")
      template('payload.rb.erb', to)
    end

    def omit_spec_payload?
      @options['no-payload']
    end

    def generate_strong_resource
      code = <<-STR
  strong_resource :#{file_name} do
    # Your attributes go here, e.g.
    # attribute :name, :string
  end

      STR
      inject_into_file 'config/initializers/strong_resources.rb', after: "StrongResources.configure do\n" do
        code
      end
    end

    def omit_strong_resource?
      @options['no-strong-resources']
    end

    def generate_route
      code = <<-STR
      resources :#{type}
      STR
      inject_into_file 'config/routes.rb', after: "scope path: '/v1' do\n" do
        code
      end
    end

    def omit_route?
      @options['no-route']
    end

    def generate_tests
      to = File.join "spec/api/v1/#{file_name.pluralize}",
        class_path,
        "index_spec.rb"
      template('index_request_spec.rb.erb', to)

      to = File.join "spec/api/v1/#{file_name.pluralize}",
        class_path,
        "show_spec.rb"
      template('show_request_spec.rb.erb', to)

      to = File.join "spec/api/v1/#{file_name.pluralize}",
        class_path,
        "create_spec.rb"
      template('create_request_spec.rb.erb', to)

      to = File.join "spec/api/v1/#{file_name.pluralize}",
        class_path,
        "update_spec.rb"
      template('update_request_spec.rb.erb', to)

      to = File.join "spec/api/v1/#{file_name.pluralize}",
        class_path,
        "destroy_spec.rb"
      template('destroy_request_spec.rb.erb', to)
    end

    def omit_tests?
      @options['no-test']
    end

    def generate_resource
      to = File.join('app/resources', class_path, "#{file_name}_resource.rb")
      template('resource.rb.erb', to)
    end

    def model_klass
      class_name.safe_constantize
    end

    def type
      model_klass.name.underscore.pluralize
    end
  end
end
