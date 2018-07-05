module JsonapiCompliable
  module Adapters
    module ActiveRecord
      module Inferrence
        def infer_foreign_key
          parent_model = parent_resource_class.model
          parent_model.reflections[association_name.to_s].foreign_key.to_sym
        end
      end
    end
  end
end
