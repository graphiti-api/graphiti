class JsonapiCompliable::Sideload::HasMany < JsonapiCompliable::Sideload
  def type
    :has_many
  end

  def load_params(parents, query)
    query.to_hash.tap do |hash|
      hash[:filter] ||= {}
      hash[:filter][foreign_key] = parents.map(&primary_key)
    end
  end

  def assign_each(parent, children)
    children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
  end
end
