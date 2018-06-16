class JsonapiCompliable::Sideload::HasOne < JsonapiCompliable::Sideload
  def type
    :has_one
  end

  def assign_each(parent, children)
    children.find { |c| c.send(foreign_key) == parent.send(primary_key) }
  end
end
