module Graphiti
  module Adapters
    class Sequel < ::Graphiti::Adapters::Abstract
      require "graphiti/adapters/sequel/inference"
      require "graphiti/adapters/sequel/has_many_sideload"
      require "graphiti/adapters/sequel/belongs_to_sideload"
      require "graphiti/adapters/sequel/has_one_sideload"
      require "graphiti/adapters/sequel/many_to_many_sideload"

      def self.sideloading_classes
        {
          has_many: Graphiti::Adapters::Sequel::HasManySideload,
          has_one: Graphiti::Adapters::Sequel::HasOneSideload,
          belongs_to: Graphiti::Adapters::Sequel::BelongsToSideload,
          many_to_many: Graphiti::Adapters::Sequel::ManyToManySideload
        }
      end

      def filter_eq(scope, attribute, value)
        scope.where(attribute => value)
      end
      alias filter_integer_eq filter_eq
      alias filter_float_eq filter_eq
      alias filter_big_decimal_eq filter_eq
      alias filter_date_eq filter_eq
      alias filter_boolean_eq filter_eq
      alias filter_uuid_eq filter_eq
      alias filter_enum_eq filter_eq

      def filter_not_eq(scope, attribute, value)
        scope.exclude(attribute => value)
      end
      alias filter_integer_not_eq filter_not_eq
      alias filter_float_not_eq filter_not_eq
      alias filter_big_decimal_not_eq filter_not_eq
      alias filter_date_not_eq filter_not_eq
      alias filter_boolean_not_eq filter_not_eq
      alias filter_uuid_not_eq filter_not_eq
      alias filter_enum_not_eq filter_not_eq

      def filter_string_eq(scope, attribute, value, is_not: false)
        filter_any(scope, attribute, value, is_not: is_not, sign: :=~, predicate: :|)  { |v| v.downcase }
      end

      def filter_string_eql(scope, attribute, value, is_not: false)
        clause = {attribute => value}
        is_not ? scope.exclude(clause) : scope.where(clause)
      end

      def filter_string_not_eq(scope, attribute, value)
        filter_string_eq(scope, attribute, value, is_not: true)
      end

      def filter_string_not_eql(scope, attribute, value)
        filter_string_eql(scope, attribute, value, is_not: true)
      end

      def filter_string_match(scope, attribute, value, is_not: false)
        filter_ilike(scope, attribute, value, is_not: is_not, pattern: "%%%s%%")
      end

      def filter_string_prefix(scope, attribute, value, is_not: false)
        filter_ilike(scope, attribute, value, is_not: is_not, pattern: "%s%%")
      end

      def filter_string_suffix(scope, attribute, value, is_not: false)
        filter_ilike(scope, attribute, value, is_not: is_not, pattern: "%%%s")
      end

      def filter_string_not_prefix(scope, attribute, value)
        filter_string_prefix(scope, attribute, value, is_not: true)
      end

      def filter_string_not_suffix(scope, attribute, value)
        filter_string_suffix(scope, attribute, value, is_not: true)
      end

      def filter_string_not_match(scope, attribute, value)
        filter_string_match(scope, attribute, value, is_not: true)
      end

      def filter_gt(scope, attribute, value)
        filter_any(scope, attribute, value, is_not: false, sign: :>, predicate: :|) { |v| v.downcase }
      end
      alias filter_integer_gt filter_gt
      alias filter_float_gt filter_gt
      alias filter_big_decimal_gt filter_gt
      alias filter_datetime_gt filter_gt
      alias filter_date_gt filter_gt

      def filter_gte(scope, attribute, value)
        filter_any(scope, attribute, value, is_not: false, sign: :>=, predicate: :|) { |v| v.downcase }
      end
      alias filter_integer_gte filter_gte
      alias filter_float_gte filter_gte
      alias filter_big_decimal_gte filter_gte
      alias filter_datetime_gte filter_gte
      alias filter_date_gte filter_gte

      def filter_lt(scope, attribute, value)
        filter_any(scope, attribute, value, is_not: false, sign: :<, predicate: :|) { |v| v.downcase }
      end
      alias filter_integer_lt filter_lt
      alias filter_float_lt filter_lt
      alias filter_big_decimal_lt filter_lt
      alias filter_datetime_lt filter_lt
      alias filter_date_lt filter_lt

      def filter_lte(scope, attribute, value)
        filter_any(scope, attribute, value, is_not: false, sign: :<=, predicate: :|) { |v| v.downcase }
      end
      alias filter_integer_lte filter_lte
      alias filter_float_lte filter_lte
      alias filter_big_decimal_lte filter_lte
      alias filter_date_lte filter_lte

      # Ensure fractional seconds don't matter
      def filter_datetime_eq(scope, attribute, value, is_not: false)
        ranges = value.map { |v| (v..v + 1.second - 0.00000001) unless v.nil? }
        clause = {attribute => ranges}
        is_not ? scope.exclude(clause) : scope.where(clause)
      end

      def filter_datetime_not_eq(scope, attribute, value)
        filter_datetime_eq(scope, attribute, value, is_not: true)
      end

      def filter_datetime_lte(scope, attribute, value)
        filter_any(scope, attribute, value, is_not: false, sign: :<=, predicate: :|) { |v| v + 1.second - 0.00000001 }
      end

      def base_scope(model)
        model.all
      end

      # (see Adapters::Abstract#order)
      def order(scope, attribute, direction)
        scope.order(Sequel.public_send(direction.to_sym, attribute.to_sym))
      end

      # (see Adapters::Abstract#paginate)
      def paginate(scope, current_page, per_page, _offset)
        scope.extension(:pagination).paginate(current_page, per_page)
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
        scope.avg(attr).to_f
      end

      # (see Adapters::Abstract#sum)
      def sum(scope, attr)
        scope.sum(attr)
      end

      # (see Adapters::Abstract#maximum)
      def maximum(scope, attr)
        scope.max(attr)
      end

      # (see Adapters::Abstract#minimum)
      def minimum(scope, attr)
        scope.min(attr)
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
        model_class.db.transaction do
          yield
        end
      end

      def associate_all(parent, children, association_name, association_type)
        if sequel_associate?(parent, children[0], association_name)
          children.each do |child|
            if [:many_to_many, :one_to_many].include?(association_type) &&
              [:create, :update].include?(Graphiti.context[:namespace]) &&
              !parent.public_send(association_name).exists?(child.id) &&
              child.errors.blank?

              parent.public_send("add_#{association_name}", child)
            else
              parent.public_send("#{association_name}=", child)
            end
          end
        else
          super
        end
      end

      def associate(parent, child, association_name, association_type)
        if sequel_associate?(parent, child, association_name)
          parent.public_send("#{association_name}=", child)
        else
          super
        end
      end

      # When a has_and_belongs_to_many relationship, we don't have a foreign
      # key that can be null'd. Instead, go through the ActiveRecord API.
      # @see Adapters::Abstract#disassociate
      def disassociate(parent, child, association_name, association_type)
        if [:many_to_many, :one_to_many].include?(association_type)
          parent.public_send("remove_#{association_name}", child)
        end
        # Nothing to do in the else case, happened when we merged foreign key
      end

      # (see Adapters::Abstract#create)
      def create(model_class, create_params)
        instance = model_class.new(create_params)
        instance.save
        instance
      end

      # (see Adapters::Abstract#update)
      def update(model_class, update_params)
        instance = model_class.find(update_params.only(:id))
        instance.update(update_params.except(:id))
        instance
      end

      def save(model_instance)
        model_instance.save
        model_instance
      end

      def destroy(model_instance)
        model_instance.destroy
        model_instance
      end

      def close
        DB.disconnect
      end

      private

      def filter_ilike(scope, attribute, value, is_not: false, pattern:)
        condition = value
          .map { |val| Sequel.ilike(attribute.to_sym, pattern % val.downcase) }
          .reduce(&:|)

        is_not ? scope.where(Sequel.function(:NOT, condition)) : scope.where(condition)
      end

      def filter_any(scope, attribute, value, is_not:, sign: , predicate:)
        condition = value
          .map { |val| Sequel.function(:lower, attribute.to_sym).public_send(sign, yield(val)) }
          .reduce(&predicate)

        is_not ? scope.where(Sequel.function(:NOT, condition)) : scope.where(condition)
      end

      def sequel_associate?(parent, _child, association_name)
        defined?(::Sequel) &&
          parent.is_a?(::Sequel::Model) &&
          parent.class.association_reflection(association_name)
      end
    end
  end
end
