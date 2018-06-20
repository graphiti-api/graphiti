module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class HasOneSideload < Sideload::HasOne
        include Inferrence

        def default_base_scope
          resource_class.model.all
        end

        def scope(parents)
          base_scope.where(foreign_key => parents.map(&primary_key))
        end
      end
    end
  end
end
