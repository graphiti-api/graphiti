module JsonapiCompliable
  module Adapters
    module ActiveRecord # todo change
      class HasManySideload < Sideload::HasMany
        include Inferrence

        def default_base_scope
          resource_class.config[:model].all
        end

        def scope(parents)
          parent_ids = parents.map(&primary_key)
          parent_ids.compact!
          parent_ids.uniq!
          base_scope.where(foreign_key => parent_ids)
        end
      end
    end
  end
end
