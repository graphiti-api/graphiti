module JsonapiCompliable
  module Scoping
    class Base
      attr_reader :resource, :query_hash

      def initialize(resource, query_hash, scope, opts = {})
        @query_hash = query_hash
        @resource   = resource
        @scope      = scope
        @opts       = opts
      end

      def apply
        if apply?
          apply_standard_or_override
        else
          @scope
        end
      end

      def apply?
        true
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
