module Graphiti
  module Util
    class RemoteSerializer
      def self.for(base, models)
        new(base).generate(models)
      end

      def initialize(base)
        @serializer = ::Class.new(base)
        @serializer.type { @object._type }
      end

      def generate(models)
        models.each do |model|
          model.to_h.each_pair do |key, value|
            if key == :_relationships
              add_relationships(value)
            elsif add_attribute?(model, key)
              @serializer.attribute(key)
            end
          end
        end
        post_process(@serializer, models)
        @serializer
      end

      private

      def add_relationships(relationship_hash)
        relationship_hash.each_pair do |name, reldata|
          @serializer.relationship(name.to_sym)
        end
      end

      def add_attribute?(model, name)
        disallow = [:_type, :id].include?(name)
        pre_existing = @serializer.attribute_blocks[name]
        is_relationship = model._relationships.try(:[], name.to_s)
        !disallow && !pre_existing && !is_relationship
      end

      def post_process(serializer, models)
        models.each do |model|
          model.delete_field(:_relationships)
          # If this isn't set, Array(resources) will return []
          # This is important, because jsonapi-serializable makes this call
          model.instance_variable_set(:@__graphiti_resource, 1)
          model.instance_variable_set(:@__graphiti_serializer, serializer)
        end
      end
    end
  end
end
