module Graphiti
  module Scoping
    # The interface for scoping logic (filter, paginate, etc).
    #
    # This class defines some common behavior, such as falling back on
    # a default if not part of the user request.
    #
    # @attr_reader [Resource] resource The corresponding Resource instance
    # @attr_reader [Hash] query_hash the Query#hash node relevant to the current resource
    #
    # @see Scoping::DefaultFilter
    # @see Scoping::ExtraFields
    # @see Scoping::Filter
    # @see Scoping::Paginate
    # @see Scoping::Sort
    # @see Scope#initialize
    # @see Scope#query_hash
    # @see Query#hash
    class Base
      attr_reader :resource, :query_hash

      # @param [Resource] resource the Resource instance
      # @param [Hash] query_hash the Query#to_hash node relevant to the current resource
      # @param scope the base scope object to chain/modify
      # @param [Hash] opts configuration options used by subclasses
      def initialize(resource, query_hash, scope, opts = {})
        @query_hash = query_hash
        @resource = resource
        @scope = scope
        @opts = opts
      end

      # Apply this scoping criteria.
      # This is where we would chain on pagination, sorting, etc.
      #
      # If #apply? returns false, does nothing. Otherwise will apply
      # the default logic:
      #
      #   # no block, run default logic via adapter
      #   allow_filter :name
      #
      # Or the customized proc:
      #
      #   allow_filter :name do |scope, value|
      #     scope.where("upper(name) = ?", value.upcase)
      #   end
      #
      # @see #apply?
      # @return the scope object
      def apply
        if apply?
          apply_standard_or_override
        else
          @scope
        end
      end

      # Should we process this scope logic?
      #
      # Useful for when we want to explicitly opt-out on
      # certain requests, or avoid a default in certain contexts.
      #
      # @return [Boolean] if we should apply this scope logic
      def apply?
        true
      end

      # Defines how to call/apply the default scoping logic
      def apply_standard_scope
        raise "override in subclass"
      end

      # Defines how to call/apply the custom scoping logic provided by the
      # user.
      def apply_custom_scope
        raise "override in subclass"
      end

      private

      # If the user customized (by providing a block in the Resource DSL)
      # then call the custom proc. Else, call the default proc.
      def apply_standard_or_override
        @scope = if apply_standard_scope?
          apply_standard_scope
        else
          apply_custom_scope
        end

        @scope
      end

      # Should we apply the default proc, or a custom one?
      def apply_standard_scope?
        custom_scope.nil?
      end
    end
  end
end
