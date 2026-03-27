module Graphiti
  module Adapters
    module Persistence
      module Associations
        def process_nullified_belongs_to_associations(persistence, attributes)
          persistence.iterate(only: { relationship_types: [:polymorphic_belongs_to, :belongs_to], method_types: [:nullify] }) do |x|
            update_foreign_key(persistence, attributes, x)
          end
        end

        def process_nullified_has_many_associations(persistence, caller_model)
          [].tap do |processed|
            persistence.iterate(only: { method_types: [:nullify] }, except: { relationship_types: [:polymorphic_belongs_to, :belongs_to] }) do |x|
              update_foreign_key(caller_model, x[:attributes], x)

              # Find the actual model instance and save the nullification
              model_instance = x[:resource].find(x[:attributes][:id]) if x[:attributes][:id]
              if model_instance
                x[:attributes].each do |k, v|
                  setter = "#{k}="
                  if model_instance.respond_to?(setter)
                    model_instance.send(setter, v)
                  else
                    raise NoMethodError, "[Graphiti] Error: #{model_instance.class} does not respond to #{setter} while nullifying relationship."
                  end
                end
                model_instance.save
              end

              # Nullify all related child records by updating PORO::DB.data directly
              if x[:foreign_key] && caller_model && x[:resource].model && PORO::DB.data[x[:resource].model.type]
                PORO::DB.data[x[:resource].model.type].each do |attrs|
                  if attrs[x[:foreign_key]] == caller_model.id
                    attrs[x[:foreign_key]] = nil
                  end
                end
              end

              x[:object] = x[:resource]
                .persist_with_relationships(x[:meta], x[:attributes], x[:relationships], caller_model, x[:foreign_key])

              processed << x
              update_foreign_key(caller_model, x[:attributes], x)

              # Find and update the actual model instance for nullification
              if x[:attributes][:id]
                model_instance = x[:resource].find(x[:attributes][:id])
                if model_instance && x[:foreign_key]
                  setter = "#{x[:foreign_key]}="
                  if model_instance.respond_to?(setter)
                    model_instance.send(setter, nil)
                  else
                    raise NoMethodError, "[Graphiti] Error: #{model_instance.class} does not respond to #{setter} while nullifying relationship."
                  end
                  model_instance.save
                end
              end

              x[:object] = x[:resource]
                .persist_with_relationships(x[:meta], x[:attributes], x[:relationships], caller_model, x[:foreign_key])

              processed << x
            end
          end
        end

        def process_belongs_to(persistence, attributes)

          parents = [].tap do |processed|
            persistence.iterate(only: { relationship_types: [:polymorphic_belongs_to, :belongs_to] }, except: { method_types: [:nullify] }) do |x|
              begin
                id = x.dig(:attributes, :id)
                x[:object] = x[:resource]
                  .persist_with_relationships(x[:meta], x[:attributes], x[:relationships])
                processed << x
              rescue Graphiti::Errors::RecordNotFound
                if Graphiti.config.raise_on_missing_sidepost
                  path = "relationships/#{x.dig(:meta, :jsonapi_type)}"
                  raise Graphiti::Errors::RecordNotFound.new(x[:sideload].name, id, path)
                else
                  pointer = "data/relationships/#{x.dig(:meta, :jsonapi_type)}"
                  object = Graphiti::Errors::NullRelation.new(id.to_s, pointer)
                  object.errors.add(:base, :not_found, message: "could not be found")
                  x[:object] = object
                  processed << x
                end
              end
            end
          end

          update_foreign_key_for_parents(parents, attributes)
          parents
        end

        def process_has_many(persistence, caller_model)
          [].tap do |processed|
            persistence.iterate(except: { relationship_types: [:polymorphic_belongs_to, :belongs_to], method_types: [:nullify] }) do |x|
              update_foreign_key(caller_model, x[:attributes], x)

              x[:object] = x[:resource]
                .persist_with_relationships(x[:meta], x[:attributes], x[:relationships], caller_model, x[:foreign_key])

              processed << x
            end
          end
        end

        def update_foreign_key_for_parents(parents, attributes)
          parents.each do |x|
            update_foreign_key(x[:object], attributes, x)
          end
        end

        # The child's attributes should be modified to nil-out the
        # foreign_key when the parent is being destroyed or disassociated
        #
        # This is not the case for HABTM, whose "foreign key" is a join table
        def update_foreign_key(parent_object, attrs, x)
          return if x[:sideload].type == :many_to_many

          if [:destroy, :disassociate, :nullify].include?(x[:meta][:method])
            if x[:sideload].polymorphic_has_one? || x[:sideload].polymorphic_has_many?
              attrs[:"#{x[:sideload].polymorphic_as}_type"] = nil
            end
            attrs[x[:foreign_key]] = nil
            update_foreign_type(attrs, x, null: true) if x[:is_polymorphic]
          else
            if x[:sideload].polymorphic_has_one? || x[:sideload].polymorphic_has_many?
              attrs[:"#{x[:sideload].polymorphic_as}_type"] = parent_object.class.name
            end
            attrs[x[:foreign_key]] = parent_object.send(x[:primary_key])
            update_foreign_type(attrs, x) if x[:is_polymorphic]
          end
        end

        def update_foreign_type(attrs, x, null: false)
          grouping_field = x[:sideload].parent.grouper.field_name
          attrs[grouping_field] = null ? nil : x[:sideload].group_name
        end
      end
    end
  end
end
