module Graphiti::Adapters::ActiveRecord::Inferrence
  # If going AR to AR, use AR introspection
  # If going AR to PORO, fall back to normal inferrence
  def infer_foreign_key
    parent_model = parent_resource_class.model
    reflection = parent_model.reflections[association_name.to_s]
    if reflection
      reflection = proper_reflection(reflection)
      reflection.foreign_key.to_sym
    else
      super
    end
  end

  private

  def proper_reflection(reflection)
    if (thru = reflection.through_reflection)
      proper_reflection(thru)
    else
      reflection
    end
  end
end
