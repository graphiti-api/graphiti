module JsonapiCompliable
  module Extensions
    module BooleanAttribute
      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        def boolean_attribute(name, options = {}, &blk)
          blk ||= proc { @object.public_send(name) }
          field_name = :"is_#{name.to_s.gsub('?', '')}"
          attribute field_name, options, &blk
        end
      end
    end
  end
end

JSONAPI::Serializable::Resource.class_eval do
  include JsonapiCompliable::Extensions::BooleanAttribute
end
