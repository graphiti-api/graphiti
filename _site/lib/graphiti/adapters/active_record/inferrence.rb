module Graphiti
  module Adapters
    module ActiveRecord
      module Inferrence
        # If going AR to AR, use AR introspection
        # If going AR to PORO, fall back to normal inferrence
        def infer_foreign_key
          parent_model = parent_resource_class.model
          reflection = parent_model.reflections[association_name.to_s]
          if reflection
            reflection.foreign_key.to_sym
          else
            super
          end
        end
      end
    end
  end
end
