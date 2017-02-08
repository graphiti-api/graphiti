module JsonapiCompliable
  class Scoping::Sort < Scoping::Base
    def custom_scope
      resource.sorting
    end

    def apply_standard_scope
      each_sort do |attribute, direction|
        @scope = resource.adapter.order(@scope, attribute, direction)
      end
      @scope
    end

    def apply_custom_scope
      each_sort do |attribute, direction|
        @scope = custom_scope.call(@scope, attribute, direction)
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
