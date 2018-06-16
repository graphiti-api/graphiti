class JsonapiCompliable::Sideload::HasMany < JsonapiCompliable::Sideload
  def type
    :has_many
  end

  def assign_each(parent, children)
    children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
  end
end
