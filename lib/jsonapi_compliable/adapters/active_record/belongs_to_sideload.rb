module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class BelongsToSideload < Sideload::BelongsTo
        include Inferrence

        def default_base_scope
          resource_class.model.all
        end

        def scope(parent_ids)
          base_scope.where(primary_key => parent_ids)
        end
      end
    end
  end
end
