class Graphiti::Sideload::HasOne < Graphiti::Sideload::HasMany
  def type
    :has_one
  end

  def assign_each(parent, children)
    children_hash = children.group_by(&foreign_key)
    result = children_hash[parent.send(primary_key)] || []
    result[0]
  end
end
