module JSONAPICompliable
  module Scope
    class Base
      attr_reader :controller, :dsl, :params, :scope

      def initialize(controller, scope)
        @controller = controller
        @dsl        = controller._jsonapi_compliable
        @params     = controller.params
        @scope      = scope
      end

      def apply
        apply_standard_or_override
      end

      def apply_standard_or_override
        if apply_standard_scope?
          @scope = apply_standard_scope
        else
          @scope = apply_custom_scope
        end

        @scope
      end

      def apply_standard_scope?
        custom_scope.nil?
      end

      def apply_standard_scope
        raise 'override in subclass'
      end

      def apply_custom_scope
        raise 'override in subclass'
      end
    end
  end
end
