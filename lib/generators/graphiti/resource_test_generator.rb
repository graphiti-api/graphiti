$:.unshift File.dirname(__FILE__)
require 'generator_mixin'

module Graphiti
  class ResourceTestGenerator < ::Rails::Generators::Base
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
      generate_resource_specs
    end

    private

    def var
      dir.singularize
    end

    def dir
      @resource.gsub('Resource', '').underscore.pluralize
    end

    def generate_resource_specs
      if actions?('create', 'update', 'destroy')
        to = "spec/resource/#{var}/writes_spec.rb.rb"
        template('resource_writes_spec.rb.erb', to)
      end

      if actions?('index', 'show')
        to = "spec/resource/#{var}/reads_spec.rb.rb"
        template('resource_reads_spec.rb.erb', to)
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
