require 'jsonapi/serializable/conditional_fields'

module JsonapiCompliable
  module Extensions
    module ExtraAttribute
      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        def extra_attribute(name, options = {}, &blk)
          allow_field = proc {
            if options[:if]
              next false unless instance_eval(&options[:if])
            end

            if @extra_fields && @extra_fields[jsonapi_type]
              @extra_fields[jsonapi_type].include?(name)
            else
              false
            end
          }

          attribute name, if: allow_field, &blk
        end
      end
    end
  end
end

JSONAPI::Serializable::Resource.class_eval do
  prepend JSONAPI::Serializable::ConditionalFields
  include JsonapiCompliable::Extensions::ExtraAttribute
end
