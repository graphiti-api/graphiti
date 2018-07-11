module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class HasOneSideload < Sideload::HasOne
        include Inferrence

        def default_base_scope
          resource_class.model.all
        end

        def scope(parent_ids)
          base_scope.where(foreign_key => parent_ids)
        end
      end
    end
  end
end
