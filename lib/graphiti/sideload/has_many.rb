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
    { foreign_key => ids_for_parents(parents).join(',') }
  end

  def assign_each(parent, children)
    children_hash = children.group_by(&foreign_key)
    children_hash[parent.send(primary_key)] || []
  end
end
