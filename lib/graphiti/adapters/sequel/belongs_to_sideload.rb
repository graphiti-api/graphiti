class Graphiti::Adapters::Sequel::BelongsToSideload < Graphiti::Sideload::BelongsTo
  include Graphiti::Adapters::Sequel::Inference

  def default_base_scope
    resource_class.model.all
  end

  def scope(parent_ids)
    base_scope.where(primary_key => parent_ids)
  end
end
