module Graphiti
  module Adapters
    class Abstract
      require "graphiti/adapters/persistence/associations"
      include Graphiti::Adapters::Persistence::Associations

      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      # You want to override this!
      # Map of association_type => sideload_class
      # e.g.
      # { has_many: Adapters::ActiveRecord::HasManySideload }
      def self.sideloading_classes
        {
          has_many: ::Graphiti::Sideload::HasMany,
          belongs_to: ::Graphiti::Sideload::BelongsTo,
          has_one: ::Graphiti::Sideload::HasOne,
          many_to_many: ::Graphiti::Sideload::ManyToMany,
          polymorphic_belongs_to: ::Graphiti::Sideload::PolymorphicBelongsTo
        }
      end

      def self.default_operators
        {
          string: [
            :eq,
            :not_eq,
            :eql,
            :not_eql,
            :prefix,
            :not_prefix,
            :suffix,
            :not_suffix,
            :match,
            :not_match
          ],
          uuid: [:eq, :not_eq],
          enum: [:eq, :not_eq, :eql, :not_eql],
          integer_id: numerical_operators,
          integer: numerical_operators,
          big_decimal: numerical_operators,
          float: numerical_operators,
          boolean: [:eq],
          date: numerical_operators,
          datetime: numerical_operators,
          hash: [:eq],
          array: [:eq]
        }
      end

      def filter_string_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_eq)
      end

      def filter_string_eql(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_eql)
      end

      def filter_string_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_not_eq)
      end

      def filter_string_not_eql(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_not_eql)
      end

      def filter_string_prefix(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_prefix)
      end

      def filter_string_not_prefix(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_not_prefix)
      end

      def filter_string_suffix(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_suffix)
      end

      def filter_string_not_suffix(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_not_suffix)
      end

      def filter_string_match(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_match)
      end

      def filter_string_not_match(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_string_not_match)
      end

      def filter_uuid_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_uuid_eq)
      end

      def filter_uuid_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_uuid_not_eq)
      end

      def filter_integer_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_eq)
      end

      def filter_integer_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_not_eq)
      end

      def filter_integer_gt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_gt)
      end

      def filter_integer_gte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_gte)
      end

      def filter_integer_lt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_lt)
      end

      def filter_integer_lte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_integer_lte)
      end

      def filter_float_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_eq)
      end

      def filter_float_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_not_eq)
      end

      def filter_float_gt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_gt)
      end

      def filter_float_gte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_gte)
      end

      def filter_float_lt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_lt)
      end

      def filter_float_lte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_float_lte)
      end

      def filter_big_decimal_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_eq)
      end

      def filter_big_decimal_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_not_eq)
      end

      def filter_big_decimal_gt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_gt)
      end

      def filter_big_decimal_gte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_gte)
      end

      def filter_big_decimal_lt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_lt)
      end

      def filter_big_decimal_lte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_decimal_lte)
      end

      def filter_datetime_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_eq)
      end

      def filter_datetime_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_not_eq)
      end

      def filter_datetime_gt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_gt)
      end

      def filter_datetime_gte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_gte)
      end

      def filter_datetime_lt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_lt)
      end

      def filter_datetime_lte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_datetime_lte)
      end

      def filter_date_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_eq)
      end

      def filter_date_not_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_not_eq)
      end

      def filter_date_gt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_gt)
      end

      def filter_date_gte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_gte)
      end

      def filter_date_lt(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_lt)
      end

      def filter_date_lte(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_date_lte)
      end

      def filter_boolean_eq(scope, attribute, value)
        raise Errors::AdapterNotImplemented.new(self, attribute, :filter_boolean_eq)
      end

      def base_scope(model)
        raise "you must override #base_scope in an adapter subclass"
      end

      # @param scope The scope object we are chaining
      # @param [Symbol] attribute The attribute name we are sorting
      # @param [Symbol] direction The direction we are sorting (asc/desc)
      # @return the scope
      #
      # @example ActiveRecord default
      #   def order(scope, attribute, direction)
      #     scope.order(attribute => direction)
      #   end
      def order(scope, attribute, direction)
        raise "you must override #order in an adapter subclass"
      end

      # @param scope The scope object we are chaining
      # @param [Integer] current_page The current page number
      # @param [Integer] per_page The number of results per page
      # @param [Integer] offset The offset to start from
      # @return the scope
      #
      # @example ActiveRecord default
      #   # via kaminari gem
      #   def paginate(scope, current_page, per_page, offset)
      #     scope.page(current_page).per(per_page)
      #   end
      def paginate(scope, current_page, per_page, offset)
        raise "you must override #paginate in an adapter subclass"
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the count of the scope
      # @example ActiveRecord default
      #   def count(scope, attr)
      #     column = attr == :total ? :all : attr
      #     scope.uniq.count(column)
      #   end
      def count(scope, attr)
        raise "you must override #count in an adapter subclass"
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Float] the average of the scope
      # @example ActiveRecord default
      #   def average(scope, attr)
      #     scope.average(attr).to_f
      #   end
      def average(scope, attr)
        raise "you must override #average in an adapter subclass"
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the sum of the scope
      # @example ActiveRecord default
      #   def sum(scope, attr)
      #     scope.sum(attr)
      #   end
      def sum(scope, attr)
        raise "you must override #sum in an adapter subclass"
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the maximum value of the scope
      # @example ActiveRecord default
      #   def maximum(scope, attr)
      #     scope.maximum(attr)
      #   end
      def maximum(scope, attr)
        raise "you must override #maximum in an adapter subclass"
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the maximum value of the scope
      # @example ActiveRecord default
      #   def maximum(scope, attr)
      #     scope.maximum(attr)
      #   end
      def minimum(scope, attr)
        raise "you must override #maximum in an adapter subclass"
      end

      # This method must +yield+ the code to run within the transaction.
      # This method should roll back the transaction if an error is raised.
      #
      # @param [Class] model_class The class we're operating on
      # @example ActiveRecord default
      #   def transaction(model_class)
      #     model_class.transaction do
      #       yield
      #     end
      #   end
      #
      # @see Resource.model
      def transaction(model_class)
        raise "you must override #transaction in an adapter subclass, it must yield"
      end

      # Resolve the scope. This is where you'd actually fire SQL,
      # actually make an HTTP call, etc.
      #
      # @example ActiveRecordDefault
      #   def resolve(scope)
      #     scope.to_a
      #   end
      #
      # @example Suggested Customization
      #   # When making a service call, we suggest this abstraction
      #   # 'scope' here is a hash
      #   def resolve(scope)
      #     # The implementation of .where can be whatever you want
      #     SomeModelClass.where(scope)
      #   end
      #
      # @see Adapters::ActiveRecord#resolve
      # @param scope The scope object to resolve
      # @return an array of Model instances
      def resolve(scope)
        scope
      end

      def belongs_to_many_filter(sideload, scope, value)
        raise "You must implement #belongs_to_many_filter in an adapter subclass"
      end

      def associate_all(parent, children, association_name, association_type)
        if activerecord_associate?(parent, children[0], association_name)
          activerecord_adapter.associate_all parent,
            children, association_name, association_type
        else
          children.each do |c|
            associate(parent, c, association_name, association_type)
          end
        end
      end

      def associate(parent, child, association_name, association_type)
        if activerecord_associate?(parent, child, association_name)
          activerecord_adapter.associate \
            parent, child, association_name, association_type
        elsif [:has_many, :many_to_many].include?(association_type)
          if parent.send(:"#{association_name}").nil?
            parent.send(:"#{association_name}=", [child])
          else
            parent.send(:"#{association_name}") << child
          end
        else
          parent.send(:"#{association_name}=", child)
        end
      end

      def disassociate(parent, child, association_name, association_type)
        raise "you must override #disassociate in an adapter subclass"
      end

      def build(model_class)
        model_class.new
      end

      # TODO respond to and specific error
      def assign_attributes(model_instance, attributes)
        attributes.each_pair do |k, v|
          model_instance.send(:"#{k}=", v)
        end
      end

      def save(model_instance)
        raise "you must override #save in an adapter subclass"
      end

      def destroy(model_instance)
        raise "you must override #destroy in an adapter subclass"
      end

      def close
      end

      def persistence_attributes(persistance, attributes)
        attributes
      end

      def self.numerical_operators
        [:eq, :not_eq, :gt, :gte, :lt, :lte].freeze
      end

      def can_group?
        false
      end

      private

      def activerecord_adapter
        @activerecord_adapter ||=
          ::Graphiti::Adapters::ActiveRecord.new(resource)
      end

      def activerecord_associate?(parent, child, association_name)
        defined?(::ActiveRecord) &&
          parent.is_a?(::ActiveRecord::Base) &&
          parent.class.reflect_on_association(association_name)
      end
    end
  end
end
