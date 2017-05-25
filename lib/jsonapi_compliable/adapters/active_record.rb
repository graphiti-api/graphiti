require 'jsonapi_compliable/adapters/active_record_sideloading'

module JsonapiCompliable
  module Adapters
    # @see Adapters::Abstract
    class ActiveRecord < Abstract
      # (see Adapters::Abstract#filter)
      def filter(scope, attribute, value)
        scope.where(attribute => value)
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

      # (see Adapters::Abstract#sideloading_module)
      def sideloading_module
        JsonapiCompliable::Adapters::ActiveRecordSideloading
      end

      # When a has_many relationship, we need to avoid Activerecord implicitly
      # firing a query. Otherwise, simple assignment will do
      # @see Adapters::Abstract#associate
      def associate(parent, child, association_name, association_type)
        if association_type == :has_many
          parent.association(association_name).loaded!
          parent.association(association_name).add_to_target(child, :skip_callbacks)
        else
          child.send("#{association_name}=", parent)
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
