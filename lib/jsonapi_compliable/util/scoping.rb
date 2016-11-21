module JsonapiCompliable
  module Util
    class Scoping
      def self.apply?(controller, object, force)
        return false if force == false
        return true if controller._jsonapi_scope.nil? && object.is_a?(ActiveRecord::Relation)

        already_scoped = !!controller._jsonapi_scope
        is_activerecord = object.is_a?(ActiveRecord::Base)
        is_activerecord_array = object.is_a?(Array) && object[0].is_a?(ActiveRecord::Base)

        if [already_scoped, is_activerecord, is_activerecord_array].any?
          false
        else
          true
        end
      end
    end
  end
end
