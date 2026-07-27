module Graphiti
  module Adapters
    # The Null adapter is a 'pass-through' adapter. It won't modify the scope.
    # Useful when your customization does not support all possible
    # configuration (e.g. the service you hit does not support sorting)
    class Null < Abstract
      def filter_string_eq(scope, attribute, value)
        scope
      end

      def filter_string_eql(scope, attribute, value)
        scope
      end

      def filter_string_not_eq(scope, attribute, value)
        scope
      end

      def filter_string_not_eql(scope, attribute, value)
        scope
      end

      def filter_string_prefix_eq(scope, attribute, value)
        scope
      end

      def filter_string_not_prefix_eq(scope, attribute, value)
        scope
      end

      def filter_string_suffix_eq(scope, attribute, value)
        scope
      end

      def filter_string_not_suffix_eq(scope, attribute, value)
        scope
      end

      def filter_string_match_eq(scope, attribute, value)
        scope
      end

      def filter_string_not_match_eq(scope, attribute, value)
        scope
      end

      def filter_integer_eq(scope, attribute, value)
        scope
      end

      def filter_integer_not_eq(scope, attribute, value)
        scope
      end

      def filter_integer_gt(scope, attribute, value)
        scope
      end

      def filter_integer_gte(scope, attribute, value)
        scope
      end

      def filter_integer_lt(scope, attribute, value)
        scope
      end

      def filter_integer_lte(scope, attribute, value)
        scope
      end

      def filter_float_eq(scope, attribute, value)
        scope
      end

      def filter_float_not_eq(scope, attribute, value)
        scope
      end

      def filter_float_gt(scope, attribute, value)
        scope
      end

      def filter_float_gte(scope, attribute, value)
        scope
      end

      def filter_float_lt(scope, attribute, value)
        scope
      end

      def filter_float_lte(scope, attribute, value)
        scope
      end

      def filter_decimal_eq(scope, attribute, value)
        scope
      end

      def filter_decimal_not_eq(scope, attribute, value)
        scope
      end

      def filter_decimal_gt(scope, attribute, value)
        scope
      end

      def filter_decimal_gte(scope, attribute, value)
        scope
      end

      def filter_decimal_lt(scope, attribute, value)
        scope
      end

      def filter_decimal_lte(scope, attribute, value)
        scope
      end

      def filter_datetime_eq(scope, attribute, value)
        scope
      end

      def filter_datetime_not_eq(scope, attribute, value)
        scope
      end

      def filter_datetime_gt(scope, attribute, value)
        scope
      end

      def filter_datetime_gte(scope, attribute, value)
        scope
      end

      def filter_datetime_lt(scope, attribute, value)
        scope
      end

      def filter_datetime_lte(scope, attribute, value)
        scope
      end

      def filter_date_eq(scope, attribute, value)
        scope
      end

      def filter_date_not_eq(scope, attribute, value)
        scope
      end

      def filter_date_gt(scope, attribute, value)
        scope
      end

      def filter_date_gte(scope, attribute, value)
        scope
      end

      def filter_date_lt(scope, attribute, value)
        scope
      end

      def filter_date_lte(scope, attribute, value)
        scope
      end

      def filter_boolean_eq(scope, attribute, value)
        scope
      end

      def filter_uuid_eq(scope, attribute, value)
        scope
      end

      def filter_uuid_not_eq(scope, attribute, value)
        scope
      end

      def base_scope(model)
        {}
      end

      # (see Adapters::Abstract#order)
      def order(scope, attribute, direction)
        scope
      end

      # (see Adapters::Abstract#paginate)
      def paginate(scope, current_page, per_page, offset)
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

      def save(model)
        model.valid? if model.respond_to?(:valid?)
        model
      end
    end
  end
end
