class Graphiti::Sideload::BelongsTo < Graphiti::Sideload
  def type
    :belongs_to
  end

  def default_render_resource_ids?
    case parent_resource_class&.belongs_to_resource_ids_by_default
    when :always then renderable_at_all?
    when :never then false
    else resource_ids_from_foreign_key?
    end
  end

  def renderable_at_all?
    readable_guarded? || readable?
  end

  def resource_ids_blocker
    return :unreadable unless renderable_at_all?
    return :custom_primary_key unless foreign_key_is_related_id? || resolves_public_ids?
    return :polymorphic_child if polymorphic_child?
    return :scope_block if self.class.scope_proc
    return :params_block if self.class.params_proc
    return :base_scope if @base_scope
    return :remote if remote?
    return :polymorphic_resource if resource.class.polymorphic.present?

    nil
  end

  def load_params(parents, query)
    query.hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter].merge!(base_filter(parents))
    end
  end

  def base_filter(parents)
    parent_ids = ids_for_parents(parents)
    return {primary_key_filter => Graphiti::Util::InternalParam.new(parent_ids)} if primary_key_filter == :_primary_key

    {primary_key_filter => parent_ids.join(",")}
  end

  def resolves_public_ids?
    @resolves_public_ids ||= target_publishes_id? && resource_class.filters.key?(primary_key_filter)
  end

  def link_hides_primary_key?
    !target_publishes_id? || resolves_public_ids?
  end

  def register_public_id_source
    return unless target_publishes_id? && resource_class_loaded? && parent_resource_class.model_declared?

    parent_resource_class.guard_public_id_leak!(foreign_key)
  end

  def rendered_id_for(foreign_key, query)
    return foreign_key unless target_publishes_id?
    return unless resolves_public_ids?

    public_id_map(query)[foreign_key]
  end

  # The serializer reports a foreign key the record cannot answer with a better error.
  def collect_foreign_keys(parents, query)
    return unless resource_class_loaded? && resolves_public_ids?
    return unless parents.first.respond_to?(foreign_key)

    public_id_map(query).add(ids_for_parents(parents))
  end

  def primary_key_filter
    return primary_key unless target_publishes_id?
    return :_primary_key if primary_key == :id || primary_key.to_s == resource_class.model_primary_key.to_s

    primary_key
  end

  def foreign_key_is_related_id?
    primary_key_filter == :id
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

  def target_publishes_id?
    @target_publishes_id ||= Graphiti.public_ids_declared? && resource_class.publishes_public_id?
  end

  def public_id_map(query)
    query.public_id_maps.compute_if_absent(self) { Graphiti::Util::PublicIdMap.new(resource_class, primary_key_filter) }
  end

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
