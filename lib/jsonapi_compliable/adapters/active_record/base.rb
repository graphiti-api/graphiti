module JsonapiCompliable
  module Adapters
    module ActiveRecord
      class Base < ::JsonapiCompliable::Adapters::Abstract
        # (see Adapters::Abstract#filter)
        def filter(scope, attribute, value)
          scope.where(attribute => value)
        end

        def base_scope(model)
          model.all
        end

        # (see Adapters::Abstract#order)
        def order(scope, attribute, direction)
          scope.order(attribute => direction)
        end

        # (see Adapters::Abstract#paginate)
        def paginate(scope, current_page, per_page)
          scope.page(current_page).per(per_page)
        end

        # (see Adapters::Abstract#count)
        def count(scope, attr)
          if attr.to_sym == :total
            scope.distinct.count
          else
            scope.distinct.count(attr)
          end
        end

        # (see Adapters::Abstract#average)
        def average(scope, attr)
          scope.average(attr).to_f
        end

        # (see Adapters::Abstract#sum)
        def sum(scope, attr)
          scope.sum(attr)
        end

        # (see Adapters::Abstract#maximum)
        def maximum(scope, attr)
          scope.maximum(attr)
        end

        # (see Adapters::Abstract#minimum)
        def minimum(scope, attr)
          scope.minimum(attr)
        end

        # (see Adapters::Abstract#resolve)
        def resolve(scope)
          scope.to_a
        end

        # Run this write request within an ActiveRecord transaction
        # @param [Class] model_class The ActiveRecord class we are saving
        # @return Result of yield
        # @see Adapters::Abstract#transaction
        def transaction(model_class)
          model_class.transaction do
            yield
          end
        end

        def sideloading_classes
          {
            has_many: HasManySideload,
            has_one: HasOneSideload,
            belongs_to: BelongsToSideload,
            many_to_many: ManyToManySideload
          }
        end

        # TODO: maybe move to sideload classes
        # associate(parent, child) does fire in SL
        # TODO: many-to-many << should only fire when persisting (?)
        def associate(parent, child, association_name, association_type)
          association = parent.association(association_name)
          association.loaded!

          if [:has_many, :many_to_many].include?(association_type)
            if association_type == :many_to_many &&
                !parent.send(association_name).exists?(child.id)
              parent.send(association_name) << child
            else
              association.target |= [child]
            end
          else
            association.target = child
          end
        end

        # When a has_and_belongs_to_many relationship, we don't have a foreign
        # key that can be null'd. Instead, go through the ActiveRecord API.
        # @see Adapters::Abstract#disassociate
        def disassociate(parent, child, association_name, association_type)
          if association_type == :many_to_many
            parent.send(association_name).delete(child)
          else
            # Nothing to do here, happened when we merged foreign key
          end
        end

        # (see Adapters::Abstract#create)
        def create(model_class, create_params)
          instance = model_class.new(create_params)
          instance.save
          instance
        end

        # (see Adapters::Abstract#update)
        def update(model_class, update_params)
          instance = model_class.find(update_params.delete(:id))
          instance.update_attributes(update_params)
          instance
        end

        # (see Adapters::Abstract#destroy)
        def destroy(model_class, id)
          instance = model_class.find(id)
          instance.destroy
          instance
        end
      end
    end
  end
end
