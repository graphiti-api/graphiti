module Jsonapi
  class ResourceGenerator < ::Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    class_option :'no-controller', type: :boolean, default: false
    class_option :'no-serializer', type: :boolean, default: false
    class_option :'no-payload', type: :boolean, default: false
    class_option :'no-strong-resources', type: :boolean, default: false
    class_option :'no-test', type: :boolean, default: false

    desc "This generator creates a resource file at app/resources"
    def copy_resource_file
      unless @options['no-controller']
        to = File.join('app/controllers', class_path, "#{file_name.pluralize}_controller.rb")
        template('controller.rb.erb', to)
      end

      unless @options['no-serializer']
        to = File.join('app/serializers', class_path, "serializable_#{file_name}.rb")
        template('serializer.rb.erb', to)
      end

      unless 'ApplicationResource'.safe_constantize
        to = File.join('app/resources', class_path, "application_resource.rb")
        template('application_resource.rb.erb', to)
      end

      unless @options['no-payload']
        to = File.join('spec/payloads', class_path, "#{file_name}.rb")
        template('payload.rb.erb', to)
      end

      unless @options['no-strong-resources']
        inject_into_file 'config/initializers/strong_resources.rb', after: "StrongResources.configure do\n" do <<-STR
  strong_resource :#{file_name} do
    # Your attributes go here, e.g.
    # attribute :name, :string
  end

        STR
        end
      end

      unless @options['no-route']
        inject_into_file 'config/routes.rb', after: "scope '/api' do\n    scope '/v1' do\n" do <<-STR
      resources :#{type}
        STR
        end
      end

      unless @options['no-test']
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

      to = File.join('app/resources', class_path, "#{file_name}_resource.rb")
      template('resource.rb.erb', to)
    end

    private

    def model_klass
      class_name.safe_constantize
    end

    def type
      model_klass.name.underscore.pluralize
    end
  end
end
