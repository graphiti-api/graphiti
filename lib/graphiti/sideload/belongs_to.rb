class Graphiti::Sideload::BelongsTo < Graphiti::Sideload
  def initialize(name, opts)
    opts = {always_include_resource_ids: false}.merge(opts)
    super(name, opts)
  end

  def type
    :belongs_to
  end

  def load_params(parents, query)
    query.hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter].merge!(base_filter(parents))
    end
  end

  def base_filter(parents)
    parent_ids = ids_for_parents(parents)
    {primary_key => parent_ids.join(",")}
  end

  def ids_for_parents(parents)
    parent_ids = parents.map(&foreign_key)
    parent_ids.compact!
    parent_ids.uniq!
    parent_ids
  end

  def infer_foreign_key
    return parent.foreign_key if polymorphic_child?

    if resource.remote?
      namespace = namespace_for(resource.class)
      resource_name = resource.class.name
        .gsub("#{namespace}::", "")
        .gsub("Resource", "")
      if resource_name.include?(".remote")
        resource_name = resource_name.split(".remote")[0].split(".")[1]
      end
      :"#{resource_name.singularize.underscore}_id"
    else
      model = resource.model
      namespace = namespace_for(model)
      model_name = model.name.gsub("#{namespace}::", "")
      :"#{model_name.underscore}_id"
    end
  end

  private

  def child_map(children)
    children.index_by(&primary_key)
  end

  def children_for(parent, map)
    fk = parent.send(foreign_key)
    children = map[fk]
    return children if children

    keys = map.keys
    if fk.is_a?(String) && keys[0].is_a?(Integer)
      fk = fk.to_i
    elsif fk.is_a?(Integer) && keys[0].is_a?(String)
      fk = fk.to_s
    end
    map[fk] || []
  end
end
