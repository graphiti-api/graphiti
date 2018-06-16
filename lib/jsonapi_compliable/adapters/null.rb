module JsonapiCompliable
  module Adapters
    # The Null adapter is a 'pass-through' adapter. It won't modify the scope.
    # Useful when your customization does not support all possible
    # configuration (e.g. the service you hit does not support sorting)
    class Null < Abstract
      # (see Adapters::Abstract#filter)
      def filter(scope, attribute, value)
        scope
      end

      # (see Adapters::Abstract#order)
      def order(scope, attribute, direction)
        scope
      end

      # (see Adapters::Abstract#paginate)
      def paginate(scope, current_page, per_page)
        scope
      end

      # (see Adapters::Abstract#count)
      def count(scope, attr)
        scope
      end

      # (see Adapters::Abstract#average)
      def average(scope, attr)
        scope
      end

      # (see Adapters::Abstract#sum)
      def sum(scope, attr)
        scope
      end

      # (see Adapters::Abstract#sum)
      def maximum(scope, attr)
        scope
      end

      # (see Adapters::Abstract#minimum)
      def minimum(scope, attr)
        scope
      end

      # Since this is a null adapter, just yield
      # @see Adapters::ActiveRecord#transaction
      # @return Result of yield
      # @param [Class] model_class The class we're operating on
      def transaction(model_class)
        yield
      end

      # (see Adapters::Abstract#resolve)
      def resolve(scope)
        scope
      end
    end
  end
end
