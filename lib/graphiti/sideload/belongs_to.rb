class Graphiti::Sideload::BelongsTo < Graphiti::Sideload
  def type
    :belongs_to
  end

  def default_include_resource_ids?
    linkage_from_foreign_key?
  end

  # The parent already carries the foreign key, and for a plain belongs_to
  # that key *is* the related id, so linkage costs nothing. Anything that can
  # change which record the relationship resolves to, or what type it carries,
  # has to load the association instead:
  #
  #   - a scope/params block or a base_scope can filter out the record the
  #     foreign key points at, so the key would claim a relationship the API
  #     would not actually return
  #   - a polymorphic target takes its type from the record, not from the
  #     relationship, so the key alone cannot say what type the id has
  #   - a remote resource has no local foreign key to read
  #   - a custom primary_key points the relationship at some other column, so
  #     the key holds that column's value rather than the related id
  def linkage_from_foreign_key?
    # Ask before resolving #resource: an unreadable relationship renders
    # nothing, and its resource class may not even be inferrable.
    return false unless readable?
    return false unless foreign_key_is_related_id?
    return false if polymorphic_child?
    return false if self.class.scope_proc || self.class.params_proc
    return false if @base_scope
    return false if remote?
    return false if resource.class.polymorphic.present?

    true
  end

  # The foreign key can stand in for the related id only when the two hold the
  # same value. base_filter matches the key against primary_key, so pointing
  # that at another column means the key holds that column instead.
  def foreign_key_is_related_id?
    primary_key == :id
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
