class Graphiti::Adapters::ActiveRecord::ManyToManySideload < Graphiti::Sideload::ManyToMany
  def through_table_name
    @through_table_name ||= parent_resource_class.model
      .reflections[through.to_s].klass.table_name
  end

  def through_relationship_name
    foreign_key.keys.first
  end

  def infer_foreign_key
    parent_model = parent_resource_class.model
    key = parent_model.reflections[name.to_s].options[:through]
    value = parent_model.reflections[key.to_s].foreign_key.to_sym
    { key => value }
  end
end
