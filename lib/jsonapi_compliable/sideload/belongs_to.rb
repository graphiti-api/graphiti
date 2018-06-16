class JsonapiCompliable::Sideload::BelongsTo < JsonapiCompliable::Sideload
  def type
    :belongs_to
  end

  def assign_each(parent, children)
    children.find { |c| c.send(primary_key) == parent.send(foreign_key) }
  end

  def associate(parent, child)
    parent_resource.associate(parent, child, name, type)
  end

  def infer_foreign_key
    model = resource_class.config[:model]
    namespace = namespace_for(model)
    model_name = model.name.gsub("#{namespace}::", '')
    "#{model_name.underscore}_id"
  end
end
