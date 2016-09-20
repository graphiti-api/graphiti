module JsonapiCompliable
  class Scope::Sort < Scope::Base
    def custom_scope
      dsl.sorting
    end

    def apply_standard_scope
      @scope.order(attribute => direction)
    end

    def apply_custom_scope
      custom_scope.call(@scope, attribute, direction)
    end

    private

    def sort_param
      @sort_param ||= (params[:sort] || 'id')
    end

    def direction
      sort_param.starts_with?('-') ? :desc : :asc
    end

    def attribute
      sort_param.dup.sub('-', '').to_sym
    end
  end
end
