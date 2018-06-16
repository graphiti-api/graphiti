module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class ManyToManySideload < Sideload::ManyToMany
        def default_base_scope
          resource_class.config[:model].all
        end

        def through_table_name
          @through_table_name ||= parent_resource_class.config[:model]
            .reflections[through.to_s].klass.table_name
        end

        def scope(parents)
          parent_ids = parents.map { |p| p.send(primary_key) }
          parent_ids.uniq!
          parent_ids.compact!

          base_scope
            .includes(through)
            .where(through_table_name => { true_foreign_key => parent_ids })
            .distinct
        end

        def infer_foreign_key
          parent_model = parent_resource_class.config[:model]
          key = parent_model.reflections[name.to_s].options[:through]
          value = parent_model.reflections[key.to_s].foreign_key.to_sym
          { key => value }
        end
      end
    end
  end
end
