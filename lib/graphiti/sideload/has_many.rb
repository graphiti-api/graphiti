class Graphiti::Sideload::HasMany < Graphiti::Sideload
  def type
    :has_many
  end

  def load_params(parents, query)
    query.hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter].merge!(base_filter(parents))
    end
  end

  def base_filter(parents)
    {foreign_key => ids_for_parents(parents).join(",")}
  end

  private

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
