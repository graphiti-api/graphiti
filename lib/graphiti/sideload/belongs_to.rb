class Graphiti::Sideload::BelongsTo < Graphiti::Sideload
  def type
    :belongs_to
  end

  def load_params(parents, query)
    query.hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter].merge!(base_filter(parents))
    end
  end

  def load(parents, query, graph_parent)
    if ids_for_parents(parents).empty?
      []
    else
      super
    end
  end

  def base_filter(parents)
    parent_ids = ids_for_parents(parents)
    { primary_key => parent_ids.join(',') }
  end

  def ids_for_parents(parents)
    parent_ids = parents.map(&foreign_key)
    parent_ids.compact!
    parent_ids.uniq!
    parent_ids
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

  private

  def child_map(children)
    children.index_by(&primary_key)
  end

  def children_for(parent, map)
    map[parent.send(foreign_key)]
  end
end
