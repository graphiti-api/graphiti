class Graphiti::Adapters::Sequel::ManyToManySideload < Graphiti::Sideload::ManyToMany
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
    filter_for(scope, value)
  end

  def ids_for_parents(parents)
    super
  end

  private

  def filter_for(scope, value)
    scope
      .includes(through_relationship_name)
      .where(belongs_to_many_clause(value))
  end

  def belongs_to_many_clause(value)
    where = {true_foreign_key => value}

    {through_table_name => where}
  end

  def through_reflection
    through = parent_reflection.options[:through]
    parent_resource_class.model.association_reflection(through.to_s)
  end

  def parent_reflection
    parent_model = parent_resource_class.model
    parent_model.reflections[association_name.to_s]
  end

  def infer_foreign_key
    key = parent_reflection.options[:through]
    value = through_reflection[:key]
    {key => value}
  end

  def infer_inverse_association
    through_class = constantize(through_reflection[:class_name])

    foreign_reflection = through_class.association_reflection[name.to_s.singularize]
    foreign_reflection && foreign_reflection.options[:inverse_of]
  end

  def constantize(camel_cased_word)
    names = camel_cased_word.split('::')
    names.shift if names.empty? || names.first.empty?

    constant = Object
    names.each do |name|
      constant = constant.const_defined?(name, false) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end
end
