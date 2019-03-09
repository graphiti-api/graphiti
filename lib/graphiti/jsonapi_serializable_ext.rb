module Graphiti
  module JsonapiSerializableExt
    # This library looks up a serializer based on the record's class name
    # This wouldn't work for us, since a model may be associated with
    # multiple resources.
    # Instead, this variable is assigned when the query is resolved
    # To ensure we always render with the *resource* serializer
    module RendererOverrides
      def _build(object, exposures, _klass)
        resource = object.instance_variable_get(:@__graphiti_resource)
        klass = object.instance_variable_get(:@__graphiti_serializer)
        klass.new(exposures.merge(object: object, resource: resource))
      end
    end

    # See above comment
    module RelationshipOverrides
      def data
        @_resources_block = proc do
          resources = yield
          if resources.nil?
            nil
          elsif resources.respond_to?(:to_ary)
            Array(resources).map do |obj|
              klass = obj.instance_variable_get(:@__graphiti_serializer)
              resource = obj.instance_variable_get(:@__graphiti_resource)
              klass.new(@_exposures.merge(object: obj, resource: resource))
            end
          else
            klass = resources.instance_variable_get(:@__graphiti_serializer)
            resource = resources.instance_variable_get(:@__graphiti_resource)
            klass.new(@_exposures.merge(object: resources, resource: resource))
          end
        end
      end
    end

    # See above comment
    module ResourceForOverride
      def resource_for(object, options, inferrer)
        resource = object.instance_variable_get(:@__graphiti_resource)
        klass = object.instance_variable_get(:@__graphiti_serializer)
        klass.new(options.merge(object: object, resource: resource))
      end
    end

    JSONAPI::Serializable::Relationship
      .send(:prepend, RelationshipOverrides)

    if JSONAPI::Serializable.methods.include?(:resource_for)
      JSONAPI::Serializable.singleton_class.send(:prepend, ResourceForOverride)
    else
      JSONAPI::Serializable::Renderer
        .send(:prepend, RendererOverrides)
    end
  end
end
