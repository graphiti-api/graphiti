# TODO: multisort

module JsonapiCompliable
  class Scoping::Sort < Scoping::Base
    def custom_scope
      resource.sorting
    end

    def apply_standard_scope
      resource.adapter.order(@scope, attribute, direction)
    end

    def apply_custom_scope
      custom_scope.call(@scope, attribute, direction)
    end

    private

    def attribute
      sort_param[0].keys.first
    end

    def direction
      sort_param[0].values.first
    end

    def sort_param
      @sort_param ||= query_hash[:sort].empty? ? resource.default_sort : query_hash[:sort]
    end
  end
end
