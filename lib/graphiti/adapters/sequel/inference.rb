module Graphiti::Adapters::Sequel::Inference
  # If going Sequel to Sequel, use Sequel introspection
  # If going AR to PORO, fall back to normal inference
  def infer_foreign_key
    parent_model = parent_resource_class.model
    reflection = parent_model.association_reflection(association_name.to_s)
    if reflection
      reflection[:key]
    else
      super
    end
  end
end
