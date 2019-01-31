$:.unshift File.dirname(__FILE__)
require 'generator_mixin'

module Graphiti
  class ApiTestGenerator < ::Rails::Generators::Base
    include GeneratorMixin

    source_root File.expand_path('../templates', __FILE__)

    argument :resource, type: :string
    class_option :'actions',
      type: :array,
      default: nil,
      aliases: ['--actions', '-a'],
      desc: 'Array of controller actions, e.g. "index show destroy"'

    desc 'Generates rspec request specs at spec/api'
    def generate
      generate_api_specs
    end

    private

    def var
      dir.singularize
    end

    def dir
      @resource.gsub('Resource', '').underscore.pluralize
    end

    def generate_api_specs
      if actions?('index')
        to = File.join("spec", ApplicationResource.endpoint_namespace, dir, "index_spec.rb")
        template('index_request_spec.rb.erb', to)
      end

      if actions?('show')
        to = File.join("spec", ApplicationResource.endpoint_namespace, dir, "show_spec.rb")
        template('show_request_spec.rb.erb', to)
      end

      if actions?('create')
        to = File.join("spec", ApplicationResource.endpoint_namespace, dir, "create_spec.rb")
        template('create_request_spec.rb.erb', to)
      end

      if actions?('update')
        to = File.join("spec", ApplicationResource.endpoint_namespace, dir, "update_spec.rb")
        template('update_request_spec.rb.erb', to)
      end

      if actions?('destroy')
        to = File.join("spec", ApplicationResource.endpoint_namespace, dir, "destroy_spec.rb")
        template('destroy_request_spec.rb.erb', to)
      end
    end

    def resource_class
      @resource.constantize
    end

    def type
      resource_class.type
    end

    def model_class
      resource_class.model
    end
  end
end
