# For "Rails STI" behavior
# CreditCard.all # => [<Visa>, <Mastercard>, etc]
module JsonapiCompliable
  class Resource
    module Polymorphism
      def self.prepended(klass)
        klass.extend ClassMethods
      end

      def serializer_for(model)
        if polymorphic_child?
          serializer
        else
          child = self.class.resource_for_model(model)
          child.serializer
        end
      end

      def associate(parent, child, association_name, type)
        child_resource = self.class.resource_for_model(parent)
        if child_resource.sideloads[association_name]
          child_resource.adapter
            .associate(parent, child, association_name, type)
        end
      end

      module ClassMethods
        def inherited(klass)
          klass.type = nil
          klass.model = klass.infer_model
          klass.polymorphic_child = true
          super
        end

        def sideload(name)
          sl = super
          if !polymorphic_child? && sl.nil?
            children.each do |c|
              break if sl = c.sideloads[name]
            end
          end
          sl
        end

        def children
          @children ||= polymorphic.map do |klass|
            klass.is_a?(String) ? klass.safe_constantize : klass
          end
        end

        def resource_for_model(model)
          resource = children.find { |c| model.is_a?(c.model) }
          if resource.nil?
            raise Errors::PolymorphicChildNotFound.new(self, model)
          else
            resource
          end
        end
      end
    end
  end
end
