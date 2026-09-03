class Graphiti::Sideload::HasMany < Graphiti::Sideload
  def initialize(name, opts)
    @inverse_filter = opts[:inverse_filter]

    super
  end

  def type
    :has_many
  end

  def inverse_filter
    @inverse_filter || foreign_key
  end

  def load_params(parents, query)
    query.hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter].merge!(base_filter(parents))
    end
  end

  def base_filter(parents)
    {foreign_key => internal_parent_filter(parents, foreign_key)}
  end

  def link_filter(parents)
    {inverse_filter => public_parent_filter(parents)}
  end

  def link_hides_primary_key?
    return true unless links_by_public_id?

    resource_class.public_id_source_for(inverse_filter) == parent_resource_class &&
      resource_class.filter_accepts_public_ids?(inverse_filter)
  end

  def links_by_public_id?
    @links_by_public_id ||= Graphiti.public_ids_declared? && primary_key == :id && !!parent_resource_class&.publishes_public_id?
  end

  def register_public_id_source
    return unless links_by_public_id? && resource_class_loaded?
    return if parent_resource_class.abstract_class? || !parent_resource_class.model_loaded?

    Graphiti.public_id_sources.register(resource_class, inverse_filter, parent_resource_class)
    resource_class.guard_public_id_leak!(inverse_filter)
  end

  private

  def parent_filter(parents)
    ids_for_parents(parents).join(",")
  end

  def internal_parent_filter(parents, filter_name)
    return parent_filter(parents) unless resource_class.public_id_source_for(filter_name)

    Graphiti::Util::InternalParam.new(ids_for_parents(parents))
  end

  def public_parent_filter(parents)
    return parent_filter(parents) unless links_by_public_id?

    parents.map { |parent| parent_resource_class.public_id_for(parent) }.compact.uniq.join(",")
  end

  def child_map(children)
    children.group_by(&foreign_key)
  end

  def children_for(parent, map)
    pk = parent.send(primary_key)
    children = map[pk]
    return children if children

    keys = map.keys
    if pk.is_a?(String) && keys[0].is_a?(Integer)
      pk = pk.to_i
    elsif pk.is_a?(Integer) && keys[0].is_a?(String)
      pk = pk.to_s
    end
    map[pk] || []
  end
end
