class Graphiti::Adapters::ActiveRecord::ManyToManySideload < Graphiti::Sideload::ManyToMany
  def through_table_name
    @through_table_name ||= parent_resource_class.model
      .reflections[through.to_s].klass.table_name
  end

  def through_relationship_name
    foreign_key.keys.first
  end

  def belongs_to_many_filter(scope, value)
    scope
      .includes(through_relationship_name)
      .where(belongs_to_many_clause(value))
  end

  private

  def belongs_to_many_clause(value)
    where = { true_foreign_key => value }.tap do |c|
      if polymorphic?
        c[foreign_type_column] = foreign_type_value
      end
    end

    { through_table_name => where }
  end

  def foreign_type_column
    through_reflection.type
  end

  def foreign_type_value
    through_reflection.active_record.name
  end

  def polymorphic?
    !!foreign_type_column
  end

  def through_reflection
    through = parent_reflection.options[:through]
    parent_resource_class.model.reflections[through.to_s]
  end

  def parent_reflection
    parent_model = parent_resource_class.model
    parent_model.reflections[name.to_s]
  end

  def infer_foreign_key
    key = parent_reflection.options[:through]
    value = through_reflection.foreign_key.to_sym
    { key => value }
  end
end
