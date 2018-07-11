module JsonapiCompliable
  # Apply filtering logic to the scope
  #
  # If the user requests to filter a field that has not been whitelisted,
  # a +JsonapiCompliable::Errors::BadFilter+ error will be raised.
  #
  #   allow_filter :title # :title now whitelisted
  #
  # If the user requests a filter field that has been whitelisted, but
  # does not pass the associated `+:if+ clause, +BadFilter+ will be raised.
  #
  #   allow_filter :title, if: :admin?
  #
  # This will also honor filter aliases.
  #
  #   # GET /posts?filter[headline]=foo will filter on title
  #   allow_filter :title, aliases: [:headline]
  #
  # @see Adapters::Abstract#filter
  # @see Adapters::ActiveRecord#filter
  # @see Resource.allow_filter
  class Scoping::Filter < Scoping::Base
    include Scoping::Filterable

    # Apply the filtering logic.
    #
    # Loop and parse all requested filters, taking into account guards and
    # aliases. If valid, call either the default or custom filtering logic.
    # @return the scope we are chaining/modifying
    def apply
      if missing_required_filters.any?
        raise Errors::RequiredFilter.new(resource, missing_required_filters)
      end

      each_filter do |filter, value|
        @scope = filter_scope(filter, value)
      end

      @scope
    end

    private

    # If there's custom logic, run it, otherwise run the default logic
    # specified in the adapter.
    def filter_scope(filter, value)
      if custom_scope = filter.values.first[:proc]
        custom_scope.call(@scope, value, resource.context)
      else
        resource.adapter.filter(@scope, filter.keys.first, value)
      end
    end

    def each_filter
      filter_param.each_pair do |param_name, param_value|
        param_name = param_name.to_sym
        filter     = find_filter!(param_name)
        value      = param_value
        value      = value.split(',') if value.is_a?(String) && value.include?(',')
        value      = coerce_types(param_name, value)
        yield filter, value
      end
    end

    # NB - avoid Array(value) here since we might want to
    # return a single element instead of array
    def coerce_types(name, value)
      type_name = resource.all_attributes[name][:type]
      cast = ->(value) { @resource.typecast(name, value, :filterable) }
      if value.is_a?(Array)
        if type_name.to_s.starts_with?('array')
          cast.call(value)
        else
          value.map { |v| cast.call(v) }
        end
      else
        cast.call(value)
      end
    end
  end
end
