class Graphiti::Sideload::HasOne < Graphiti::Sideload::HasMany
  def type
    :has_one
  end

  private

  def children_for(parent, map)
    super[0]
  end
end
