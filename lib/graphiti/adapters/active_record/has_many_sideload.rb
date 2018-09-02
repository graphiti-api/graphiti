class Graphiti::Adapters::ActiveRecord::HasManySideload < Graphiti::Sideload::HasMany
  include Graphiti::Adapters::ActiveRecord::Inferrence

  def default_base_scope
    resource_class.model.all
  end

  def scope(parent_ids)
    base_scope.where(foreign_key => parent_ids)
  end
end
