module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class BelongsToSideload < Sideload::BelongsTo
        include Inferrence

        def default_base_scope
          resource_class.model.all
        end

        def scope(parents)
          base_scope.where(primary_key => parents.map(&foreign_key))
        end
      end
    end
  end
end
