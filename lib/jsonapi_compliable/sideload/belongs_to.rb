class JsonapiCompliable::Sideload::BelongsTo < JsonapiCompliable::Sideload
  def type
    :belongs_to
  end

  def load_params(parents, query)
    query.to_hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter][primary_key] = parents.map(&foreign_key)
    end
  end

  def assign_each(parent, children)
    children.find { |c| c.send(primary_key) == parent.send(foreign_key) }
  end

  def associate(parent, child)
    parent_resource.associate(parent, child, association_name, type)
  end

  def infer_foreign_key
    if polymorphic_child?
      parent.foreign_key
    else
      model = resource.model
      namespace = namespace_for(model)
      model_name = model.name.gsub("#{namespace}::", '')
      :"#{model_name.underscore}_id"
    end
  end
end
