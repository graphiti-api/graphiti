class Graphiti::Adapters::Sequel::HasOneSideload < Graphiti::Sideload::HasOne
  include Graphiti::Adapters::Sequel::Inference

  def default_base_scope
    resource_class.model.all
  end

  def scope(parent_ids)
    base_scope.where(foreign_key => parent_ids)
  end
end
