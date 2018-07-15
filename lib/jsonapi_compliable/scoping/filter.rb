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

      each_filter do |filter, operator, value|
        @scope = filter_scope(filter, operator, value)
      end

      @scope
    end

    private

    def filter_scope(filter, operator, value)
      operator = operator.to_s.gsub('!', 'not_').to_sym

      if custom_scope = filter.values.first[operator]
        custom_scope.call(@scope, value, resource.context)
      else
        filter_via_adapter(filter, operator, value)
      end
    end

    def filter_via_adapter(filter, operator, value)
      type_name = Types.name_for(filter.values.first[:type])
      method    = :"filter_#{type_name}_#{operator}"
      attribute = filter.keys.first

      if resource.adapter.respond_to?(method)
        resource.adapter.send(method, @scope, attribute, value)
      else
        raise Errors::AdapterNotImplemented.new \
          resource.adapter, attribute, method
      end
    end

    def each_filter
      filter_param.each_pair do |param_name, param_value|
        filter = find_filter!(param_name)
        param_value = { eq: param_value } unless param_value.is_a?(Hash)
        value = param_value.values.first
        operator = param_value.keys.first
        value = param_value.values.first unless filter.values[0][:type] == :hash
        value = value.split(',') if value.is_a?(String) && value.include?(',')
        value = coerce_types(param_name.to_sym, value)
        yield filter, operator, value
      end
    end

    def coerce_types(name, value)
      type_name = @resource.all_attributes[name][:type]
      is_array = type_name.to_s.starts_with?('array_of') ||
        Types[type_name][:canonical_name] == :array

      if is_array
        @resource.typecast(name, value, :filterable)
      else
        value = value.nil? || value.is_a?(Hash) ? [value] : Array(value)
        value.map { |v| @resource.typecast(name, v, :filterable) }
      end
    end
  end
end
