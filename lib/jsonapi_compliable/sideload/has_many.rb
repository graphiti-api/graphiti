class JsonapiCompliable::Sideload::HasMany < JsonapiCompliable::Sideload
  def type
    :has_many
  end

  def query(parents, query)
    hash = query.to_hash
    hash[:filter] ||= {}
    hash[:filter][foreign_key] = parents.map(&primary_key)

    opts = {}
    opts[:default_paginate] = false
    opts[:sideload_parent_length] = parents.length
    opts[:after_resolve] = ->(results) {
      fire_assign(parents, results)
    }

    resource.class._all(hash, opts, base_scope).to_a
  end

  def assign_each(parent, children)
    children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
  end
end
