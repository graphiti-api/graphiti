module Graphiti
  class Serializer < JSONAPI::Serializable::Resource
    include Graphiti::Extensions::BooleanAttribute
    include Graphiti::Extensions::ExtraAttribute
    include Graphiti::SerializableHash
    prepend Graphiti::SerializableTempId

    def self.inherited(klass)
      super
      klass.class_eval do
        extend JSONAPI::Serializable::Resource::ConditionalFields
      end
    end

    # Temporary fix until fixed upstream
    # https://github.com/jsonapi-rb/jsonapi-serializable/pull/102
    def requested_relationships(fields)
      @_relationships
    end

    # Allow access to resource methods
    def method_missing(id, *args, &blk)
      if @resource.respond_to?(id, true)
        @resource.send(id, *args, &blk)
      else
        super
      end
    end
  end
end
