module Graphiti
  module Adapters
    class ActiveRecord < ::Graphiti::Adapters::Abstract
      require "graphiti/adapters/active_record/inference"
      require "graphiti/adapters/active_record/has_many_sideload"
      require "graphiti/adapters/active_record/belongs_to_sideload"
      require "graphiti/adapters/active_record/has_one_sideload"
      require "graphiti/adapters/active_record/many_to_many_sideload"

      def self.sideloading_classes
        {
          has_many: Graphiti::Adapters::ActiveRecord::HasManySideload,
          has_one: Graphiti::Adapters::ActiveRecord::HasOneSideload,
          belongs_to: Graphiti::Adapters::ActiveRecord::BelongsToSideload,
          many_to_many: Graphiti::Adapters::ActiveRecord::ManyToManySideload
        }
      end

      def filter_eq(scope, attribute, value)
        scope.where(attribute => value)
      end
      alias_method :filter_integer_eq, :filter_eq
      alias_method :filter_float_eq, :filter_eq
      alias_method :filter_big_decimal_eq, :filter_eq
      alias_method :filter_date_eq, :filter_eq
      alias_method :filter_boolean_eq, :filter_eq
      alias_method :filter_uuid_eq, :filter_eq
      alias_method :filter_enum_eq, :filter_eq
      alias_method :filter_enum_eql, :filter_eq

      def filter_not_eq(scope, attribute, value)
        scope.where.not(attribute => value)
      end
      alias_method :filter_integer_not_eq, :filter_not_eq
      alias_method :filter_float_not_eq, :filter_not_eq
      alias_method :filter_big_decimal_not_eq, :filter_not_eq
      alias_method :filter_date_not_eq, :filter_not_eq
      alias_method :filter_boolean_not_eq, :filter_not_eq
      alias_method :filter_uuid_not_eq, :filter_not_eq
      alias_method :filter_enum_not_eq, :filter_not_eq
      alias_method :filter_enum_not_eql, :filter_not_eq

      def filter_string_eq(scope, attribute, value, is_not: false)
        column = column_for(scope, attribute)
        clause = column.lower.eq_any(value.map(&:downcase))
        is_not ? scope.where.not(clause) : scope.where(clause)
      end

      def filter_string_eql(scope, attribute, value, is_not: false)
        clause = {attribute => value}
        is_not ? scope.where.not(clause) : scope.where(clause)
      end

      def filter_string_not_eq(scope, attribute, value)
        filter_string_eq(scope, attribute, value, is_not: true)
      end

      def filter_string_not_eql(scope, attribute, value)
        filter_string_eql(scope, attribute, value, is_not: true)
      end

      # Arel has different match escaping behavior before rails 5.
      # Since rails 4.x does not expose methods to escape LIKE statements
      # anyway, we just don't support proper LIKE escaping in those versions.
      if ::ActiveRecord.version >= Gem::Version.new("5.0.0")
        def filter_string_match(scope, attribute, value, is_not: false)
          clause = sanitized_like_for(scope, attribute, value) { |v|
            "%#{v}%"
          }
          is_not ? scope.where.not(clause) : scope.where(clause)
        end

        def filter_string_prefix(scope, attribute, value, is_not: false)
          clause = sanitized_like_for(scope, attribute, value) { |v|
            "#{v}%"
          }
          is_not ? scope.where.not(clause) : scope.where(clause)
        end

        def filter_string_suffix(scope, attribute, value, is_not: false)
          clause = sanitized_like_for(scope, attribute, value) { |v|
            "%#{v}"
          }
          is_not ? scope.where.not(clause) : scope.where(clause)
        end
      else
        def filter_string_match(scope, attribute, value, is_not: false)
          column = column_for(scope, attribute)
          map = value.map { |v|
            "%#{v.downcase}%"
          }
          clause = column.lower.matches_any(map)
          is_not ? scope.where.not(clause) : scope.where(clause)
        end

        def filter_string_prefix(scope, attribute, value, is_not: false)
          column = column_for(scope, attribute)
          map = value.map { |v| "#{v}%" }
          clause = column.lower.matches_any(map)
          is_not ? scope.where.not(clause) : scope.where(clause)
        end

        def filter_string_suffix(scope, attribute, value, is_not: false)
          column = column_for(scope, attribute)
          map = value.map { |v| "%#{v}" }
          clause = column.lower.matches_any(map)
          is_not ? scope.where.not(clause) : scope.where(clause)
        end
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
        column = column_for(scope, attribute)
        scope.where(column.gt_any(value))
      end
      alias_method :filter_integer_gt, :filter_gt
      alias_method :filter_float_gt, :filter_gt
      alias_method :filter_big_decimal_gt, :filter_gt
      alias_method :filter_datetime_gt, :filter_gt
      alias_method :filter_date_gt, :filter_gt

      def filter_gte(scope, attribute, value)
        column = column_for(scope, attribute)
        scope.where(column.gteq_any(value))
      end
      alias_method :filter_integer_gte, :filter_gte
      alias_method :filter_float_gte, :filter_gte
      alias_method :filter_big_decimal_gte, :filter_gte
      alias_method :filter_datetime_gte, :filter_gte
      alias_method :filter_date_gte, :filter_gte

      def filter_lt(scope, attribute, value)
        column = column_for(scope, attribute)
        scope.where(column.lt_any(value))
      end
      alias_method :filter_integer_lt, :filter_lt
      alias_method :filter_float_lt, :filter_lt
      alias_method :filter_big_decimal_lt, :filter_lt
      alias_method :filter_datetime_lt, :filter_lt
      alias_method :filter_date_lt, :filter_lt

      def filter_lte(scope, attribute, value)
        column = column_for(scope, attribute)
        scope.where(column.lteq_any(value))
      end
      alias_method :filter_integer_lte, :filter_lte
      alias_method :filter_float_lte, :filter_lte
      alias_method :filter_big_decimal_lte, :filter_lte
      alias_method :filter_date_lte, :filter_lte

      # Ensure fractional seconds don't matter
      def filter_datetime_eq(scope, attribute, value, is_not: false)
        ranges = value.map { |v| (v..v + 1.second - 0.00000001) unless v.nil? }
        clause = {attribute => ranges}
        is_not ? scope.where.not(clause) : scope.where(clause)
      end

      def filter_datetime_not_eq(scope, attribute, value)
        filter_datetime_eq(scope, attribute, value, is_not: true)
      end

      def filter_datetime_lte(scope, attribute, value)
        value = value.map { |v| v + 1.second - 0.00000001 }
        column = scope.klass.arel_table[attribute]
        scope.where(column.lteq_any(value))
      end

      def base_scope(model)
        model.all
      end

      # (see Adapters::Abstract#order)
      def order(scope, attribute, direction)
        scope.order(attribute => direction)
      end

      # (see Adapters::Abstract#paginate)
      def paginate(scope, current_page, per_page, offset)
        scope = scope.page(current_page) if current_page
        scope = scope.per(per_page) if per_page
        scope = scope.padding(offset) if offset
        scope
      end

      # (see Adapters::Abstract#count)
      def count(scope, attr)
        if attr.to_sym == :total
          scope.distinct.count(:all)
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

      def associate_all(parent, children, association_name, association_type)
        if activerecord_associate?(parent, children[0], association_name)
          association = parent.association(association_name)
          association.loaded!

          children.each do |child|
            if association_type == :many_to_many &&
                [:create, :update].include?(Graphiti.context[:namespace]) &&
                !parent.send(association_name).exists?(child.id) &&
                child.errors.blank?
              parent.send(association_name) << child
            else
              target = association.instance_variable_get(:@target)
              target |= [child]
              association.instance_variable_set(:@target, target)
            end
          end
        else
          super
        end
      end

      def associate(parent, child, association_name, association_type)
        if activerecord_associate?(parent, child, association_name)
          association = parent.association(association_name)
          association.loaded!
          association.instance_variable_set(:@target, child)
        else
          super
        end
      end

      # When a has_and_belongs_to_many relationship, we don't have a foreign
      # key that can be null'd. Instead, go through the ActiveRecord API.
      # @see Adapters::Abstract#disassociate
      def disassociate(parent, child, association_name, association_type)
        if association_type == :many_to_many
          parent.send(association_name).delete(child)
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
        instance.update_attributes(update_params.except(:id))
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
        if ::ActiveRecord.version > Gem::Version.new("7.1")
          ::ActiveRecord::Base.connection_handler.clear_active_connections!
        else
          ::ActiveRecord::Base.clear_active_connections!
        end
      end

      def can_group?
        true
      end

      def group(scope, attribute)
        scope.group(attribute)
      end

      private

      def column_for(scope, name)
        table = scope.klass.arel_table
        if (other = scope.attribute_alias(name))
          table[other]
        else
          table[name]
        end
      end

      def sanitized_like_for(scope, attribute, value, &block)
        escape_char = "\\"
        column = column_for(scope, attribute)
        map = value.map { |v|
          v = v.downcase
          v = Sanitizer.sanitize_like(v, escape_char)
          block.call v
        }

        column.lower.matches_any(map, escape_char, true)
      end

      class Sanitizer
        extend ::ActiveRecord::Sanitization::ClassMethods

        def self.sanitize_like(*args)
          sanitize_sql_like(*args)
        end
      end
    end
  end
end
