module JsonapiCompliable
  # Apply sorting logic to the scope.
  #
  # By default, sorting comes 'for free'. To specify a custom sorting proc:
  #
  #   class PostResource < ApplicationResource
  #     sort do |scope, att, dir|
  #       int = dir == :desc ? -1 : 1
  #       scope.sort_by { |x| x[att] * int }
  #     end
  #   end
  #
  # The sorting proc will be called once for each sort att/dir requested.
  # @see Resource.sort
  class Scoping::Sort < Scoping::Base
    # @return [Proc, Nil] The custom proc specified by Resource DSL
    def custom_scope
      resource.sorting
    end

    # Apply default scope logic via Resource adapter
    # @return the scope we are chaining/modifying
    def apply_standard_scope
      each_sort do |attribute, direction|
        @scope = resource.adapter.order(@scope, attribute, direction)
      end
      @scope
    end

    # Apply custom scoping proc configured via Resource DSL
    # @return the scope we are chaining/modifying
    def apply_custom_scope
      each_sort do |attribute, direction|
        @scope = custom_scope
          .call(@scope, attribute, direction, resource.context)
      end
      @scope
    end

    private

    def each_sort
      sort_param.each do |sort_hash|
        yield sort_hash.keys.first, sort_hash.values.first
      end
    end

    def sort_param
      @sort_param ||= query_hash[:sort].empty? ? resource.default_sort : query_hash[:sort]
    end
  end
end
