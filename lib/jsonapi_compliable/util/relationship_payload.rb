module JsonapiCompliable
  module Util
    # Helper methods for traversing the 'relationships' JSONAPI payloads
    # @api private
    class RelationshipPayload
      attr_reader :resource, :payload

      def self.iterate(resource:, relationships: {}, only: [], except: [])
        instance = new(resource, relationships, only: only, except: except)
        instance.iterate do |sideload, relationship_data, sub_relationships|
          yield sideload, relationship_data, sub_relationships
        end
      end

      def initialize(resource, payload, only: [], except: [])
        @resource = resource
        @payload  = payload
        @only     = only
        @except   = except
      end

      def iterate
        payload.each_pair do |relationship_name, relationship_payload|
          if sl = resource.class.sideload(relationship_name.to_sym)
            if should_yield?(sl.type)
              if relationship_payload.is_a?(Array)
                relationship_payload.each do |rp|
                  yield payload_for(sl, rp)
                end
              else
                yield payload_for(sl, relationship_payload)
              end
            end
          end
        end
      end

      private

      def should_yield?(type)
        (@only.length > 0 && @only.include?(type)) ||
          (@except.length > 0 && !@except.include?(type))
      end

      def payload_for(sideload, relationship_payload)
        if sideload.polymorphic_parent?
          type     = relationship_payload[:meta][:jsonapi_type]
          sideload = sideload.child_for_type(type.to_sym)
        end
        relationship_payload[:meta][:method] ||= :update

        {
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
