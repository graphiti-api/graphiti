require 'jsonapi/serializable/resource/conditional_fields'

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

            @extra_fields[@_type] && @extra_fields[@_type].include?(name)
          }

          attribute name, if: allow_field, &blk
        end
      end
    end
  end
end

JSONAPI::Serializable::Resource.class_eval do
  prepend JSONAPI::Serializable::Resource::ConditionalFields
  include JsonapiCompliable::Extensions::ExtraAttribute
end
