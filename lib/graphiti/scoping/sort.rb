module Graphiti
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
      resource.sort_all
    end

    # Apply default scope logic via Resource adapter
    # @return the scope we are chaining/modifying
    def apply_standard_scope
      each_sort do |attribute, direction|
        resource.get_attr!(attribute, :sortable, request: true)
        sort = resource.sorts[attribute]
        if sort[:only] && sort[:only] != direction
          raise Errors::UnsupportedSort.new resource,
            attribute, sort[:only], direction
        else
          @scope = if sort[:proc]
            resource.instance_exec(@scope, direction, &sort[:proc])
          else
            resource.adapter.order(@scope, attribute, direction)
          end
        end
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
        attribute = sort_hash.keys.first
        direction = sort_hash.values.first
        yield attribute, direction
      end
    end

    def sort_param
      @sort_param ||= if query_hash[:sort].blank?
        resource.default_sort || []
      else
        normalize(query_hash[:sort])
      end
    end

    def normalize(sort)
      return sort if sort.is_a?(Array)
      sorts = sort.split(",")
      sorts.map do |s|
        sort_hash(s)
      end
    end

    def sort_hash(attr)
      value = attr[0] == "-" ? :desc : :asc
      key = attr.sub("-", "").to_sym

      {key => value}
    end
  end
end
