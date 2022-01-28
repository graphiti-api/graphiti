module Graphiti
  module Util
    # Helper methods for traversing the 'relationships' JSONAPI payloads
    # @api private
    class RelationshipPayload
      attr_reader :resource, :payload

      def self.iterate(resource:, relationships: {}, only: {}, except: {})
        instance = new(resource, relationships, only: only, except: except)
        instance.iterate do |sideload, relationship_data, sub_relationships|
          yield sideload, relationship_data, sub_relationships
        end
      end

      def initialize(resource, payload, only: {}, except: {})
        @resource = resource
        @payload = payload
        @only = only
        @except = except
      end

      def iterate
        payload.each_pair do |relationship_name, relationship_payload|
          if (sl = resource.class.sideload(relationship_name.to_sym))
            if should_yield_relationship_type?(sl.type)
              if relationship_payload.is_a?(Array)
                relationship_payload.each do |rp|
                  if should_yield_method_type?(rp.fetch(:meta, {})[:method] || :update)
                    yield payload_for(sl, rp)
                  end
                end
              else
                if should_yield_method_type?(relationship_payload.fetch(:meta, {})[:method] || :update)
                  yield payload_for(sl, relationship_payload)
                end
              end
            end
          end
        end
      end

      private

      def only_relationship_types
        @only[:relationship_types] || []
      end

      def except_relationship_types
        @except[:relationship_types] || []
      end

      def only_method_types
        @only[:method_types] || []
      end

      def except_method_types
        @except[:method_types] || []
      end

      def should_yield_method_type?(type)
        (only_method_types.length == 0 && except_method_types.length == 0) ||
          (only_method_types.length > 0 && only_method_types.include?(type)) ||
          (except_method_types.length > 0 && !except_method_types.include?(type))
      end

      def should_yield_relationship_type?(type)
        (only_relationship_types.length == 0 && except_relationship_types.length == 0) ||
          (only_relationship_types.length > 0 && only_relationship_types.include?(type)) ||
          (except_relationship_types.length > 0 && !except_relationship_types.include?(type))
      end

      def payload_for(sideload, relationship_payload)
        if relationship_payload[:meta][:method] == :nullify
          resource = sideload.resource

          {
            resource: resource,
            sideload: sideload,
            is_polymorphic: sideload.polymorphic_child?,
            primary_key: sideload.primary_key,
            foreign_key: sideload.foreign_key,
            attributes: relationship_payload[:attributes],
            meta: relationship_payload[:meta],
            relationships: relationship_payload[:relationships]
          }
        else
          type = relationship_payload[:meta][:jsonapi_type].to_sym

          # For polymorphic *sideloads*, grab the correct child sideload
          if sideload.resource.type != type && sideload.type == :polymorphic_belongs_to
            sideload = sideload.child_for_type!(type)
          end

          # For polymorphic *resources*, grab the correct child resource
          resource = sideload.resource
          if resource.type != type && resource.polymorphic?
            resource = resource.class.resource_for_type(type).new
          end

          relationship_payload[:meta][:method] ||= :update

          {
            resource: resource,
            sideload: sideload,
            is_polymorphic: sideload.polymorphic_child?,
            primary_key: sideload.primary_key,
            foreign_key: sideload.foreign_key,
            attributes: relationship_payload[:attributes],
            meta: relationship_payload[:meta],
            relationships: relationship_payload[:relationships]
          }
        end
      end
    end
  end
end
