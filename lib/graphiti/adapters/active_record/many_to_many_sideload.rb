class Graphiti::Adapters::ActiveRecord::ManyToManySideload < Graphiti::Sideload::ManyToMany
  def through_table_name
    @through_table_name ||= resource_class.model.reflections[through.to_s].klass.table_name
  end

  def through_relationship_name
    foreign_key.keys.first
  end

  def inverse_filter
    return @inverse_filter if @inverse_filter

    inferred_name = infer_inverse_association

    if inferred_name
      "#{inferred_name.to_s.singularize}_id"
    else
      super
    end
  end

  def belongs_to_many_filter(scope, value)
    if polymorphic?
      clauses = value.group_by { |v| v["type"] }.map { |group|
        ids = group[1].map { |g| g["id"] }
        filter_for(scope, ids, group[0])
      }
      scope = clauses.shift
      clauses.each { |c| scope = scope.or(c) }
      scope
    else
      filter_for(scope, value)
    end
  end

  def ids_for_parents(parents)
    if polymorphic?
      parents.group_by(&:class).map do |group|
        {id: super(group[1]), type: group[0].name}.to_json
      end
    else
      super
    end
  end

  private

  def filter_for(scope, value, type = nil)
    scope
      .includes(through_relationship_name)
      .where(belongs_to_many_clause(value, type))
  end

  def belongs_to_many_clause(value, type)
    where = {true_foreign_key => value}
    if polymorphic? && type
      where[foreign_type_column] = type
    end
    {through_table_name => where}
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
    parent_model.reflections[association_name.to_s]
  end

  def infer_foreign_key
    key = parent_reflection.options[:through]
    value = through_reflection.foreign_key.to_sym
    {key => value}
  end

  def infer_inverse_association
    through_class = through_reflection.klass

    foreign_reflection = through_class.reflections[name.to_s.singularize]
    foreign_reflection && foreign_reflection.options[:inverse_of]
  end
end
