require 'jsonapi_compliable/adapters/active_record_sideloading'

module JsonapiCompliable
  module Adapters
    class ActiveRecord < Abstract
      def filter(scope, attribute, value)
        scope.where(attribute => value)
      end

      def order(scope, attribute, direction)
        scope.order(attribute => direction)
      end

      def paginate(scope, current_page, per_page)
        scope.page(current_page).per(per_page)
      end

      def count(scope, attr)
        scope.uniq.count
      end

      def average(scope, attr)
        scope.average(attr).to_f
      end

      def sum(scope, attr)
        scope.sum(attr)
      end

      def maximum(scope, attr)
        scope.maximum(attr)
      end

      def minimum(scope, attr)
        scope.minimum(attr)
      end

      def resolve(scope)
        scope.to_a
      end

      def transaction(model_class)
        model_class.transaction do
          yield
        end
      end

      def sideloading_module
        JsonapiCompliable::Adapters::ActiveRecordSideloading
      end

      def associate(parent, child, association_name, association_type)
        if association_type == :has_many
          parent.association(association_name).loaded!
          parent.association(association_name).add_to_target(child, :skip_callbacks)
        else
          child.send("#{association_name}=", parent)
        end
      end

      def create(model_class, create_params)
        instance = model_class.new(create_params)
        instance.save
        instance
      end

      def update(model_class, update_params)
        instance = model_class.find(update_params.delete(:id))
        instance.update_attributes(update_params)
        instance
      end

      def destroy(model_class, id)
        instance = model_class.find(id)
        instance.destroy
        instance
      end
    end
  end
end
