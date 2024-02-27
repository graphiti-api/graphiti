module Graphiti
  class Scoping::Filter < Scoping::Base
    include Scoping::Filterable

    def apply
      unless @opts[:bypass_required_filters]
        Graphiti::Scoping::FilterGroupValidator.new(
          resource,
          query_hash
        ).raise_unless_filter_group_requirements_met!
      end

      if missing_required_filters.any? && !@opts[:bypass_required_filters]
        raise Errors::RequiredFilter.new(resource, missing_required_filters)
      end

      if missing_dependent_filters.any?
        raise Errors::MissingDependentFilter.new \
          resource, missing_dependent_filters
      end

      each_filter do |filter, operator, value|
        @scope = filter_scope(filter, operator, value)
      end

      resource.after_filtering(@scope)
    end

    private

    def filter_scope(filter, operator, value)
      if (custom_scope = filter.values[0][:operators][operator])
        @resource.instance_exec(@scope, value, resource.context, &custom_scope)
      else
        filter_via_adapter(filter, operator, value)
      end
    end

    def filter_via_adapter(filter, operator, value)
      type_name = Types.name_for(filter.values.first[:type])
      method = :"filter_#{type_name}_#{operator}"
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

        normalize_param(filter, param_value).each do |operator, value|
          operator = operator.to_s.gsub("!", "not_").to_sym
          validate_operator(filter, operator)

          type = Types[filter.values[0][:type]]
          unless type[:canonical_name] == :hash || !value.is_a?(String)
            value = parse_string_value(filter.values[0], value)
          end

          check_deny_empty_filters!(resource, filter, value)
          value = parse_string_null(filter.values[0], value)
          validate_singular(resource, filter, value)
          value = coerce_types(filter.values[0], param_name.to_sym, value)
          validate_allowlist(resource, filter, value)
          validate_denylist(resource, filter, value)
          value = value[0] if filter.values[0][:single]
          yield filter, operator, value
        end
      end
    end

    def coerce_types(filter, name, value)
      type_name = filter[:type]
      is_array = type_name.to_s.starts_with?("array_of") ||
        Types[type_name][:canonical_name] == :array

      if is_array
        @resource.typecast(name, value, :filterable)
      else
        value = value.nil? || value.is_a?(Hash) ? [value] : Array(value)
        value.map { |v| @resource.typecast(name, v, :filterable) }
      end
    end

    def normalize_param(filter, param_value)
      type = Types[filter.values[0][:type]][:canonical_name]
      if param_value.is_a?(Hash) && type == :hash
        operators_keys = filter.values[0][:operators].keys
        unless param_value.keys.all? { |k| operators_keys.include?(k) }
          param_value = {eq: param_value}
        end
      elsif !param_value.is_a?(Hash) || param_value.empty?
        param_value = {eq: param_value}
      end

      param_value.map do |operator, value|
        if type == :hash
          value, operator = \
            parse_hash_value(filter, param_value, value, operator)
        end

        [operator, value]
      end
    end

    def validate_operator(filter, operator)
      supported = filter.values[0][:operators].keys
      unless supported.include?(operator)
        raise Errors::UnsupportedOperator.new \
          resource, filter.keys[0], supported, operator
      end
    end

    def validate_singular(resource, filter, value)
      if filter.values[0][:single] && value.is_a?(Array)
        raise Errors::SingularFilter.new(resource, filter, value)
      end
    end

    def validate_allowlist(resource, filter, values)
      values.each do |v|
        if (allow = filter.values[0][:allow])
          unless allow.include?(v)
            raise Errors::InvalidFilterValue.new(resource, filter, v)
          end
        end
      end
    end

    def validate_denylist(resource, filter, values)
      values.each do |v|
        if (deny = filter.values[0][:deny])
          if deny.include?(v)
            raise Errors::InvalidFilterValue.new(resource, filter, v)
          end
        end
      end
    end

    def parse_hash_value(filter, param_value, value, operator)
      has_filter = resource.filters.dig(filter.keys.first, :operators, operator).present?

      if operator != :eq && !has_filter
        operator = :eq
        value = param_value
      end

      if value.is_a?(String)
        value = value.gsub("{{{", "{").gsub("}}}", "}") unless filter.values[0][:single]

        if value.include?("},{") && !filter.values[0][:single]
          value = Util::Hash.split_json(value)
        end
      end

      [value, operator]
    end

    # foo,bar,baz becomes ["foo", "bar", "baz"] (unless array type)
    # {{foo}} becomes ["foo"]
    # {{foo,bar}},baz becomes ["foo,bar", "baz"]
    #
    # JSON of
    # {{{ "id": 1 }}} becomes { 'id' => 1 }
    def parse_string_value(filter, value)
      type = Graphiti::Types[filter[:type]]
      array_or_string = [:string, :array].include?(type[:canonical_name])
      if (arr = value.scan(/\[.*?\]/)).present? && array_or_string
        begin
          value = arr.map { |json|
            begin
              JSON.parse(json)
            rescue
              raise Errors::InvalidJSONArray.new(resource, value)
            end
          }
          value = value[0] if value.length == 1
        rescue Errors::InvalidJSONArray => e
          raise(e) if type[:canonical_name] == :array
        end
      else
        value = parse_string_arrays(value, !!filter[:single])
      end
      value
    end

    def parse_string_arrays(value, singular_filter)
      # Find the quoted strings
      quotes = value.scan(/{{.*?}}/)
      # remove them from the rest
      non_quotes = quotes.inject(value) { |v, q| v.gsub(q, "") }
      # remove the quote characters from the quoted strings
      quotes.each { |q| q.gsub!("{{", "").gsub!("}}", "") }
      # merge everything back together into an array
      value = if singular_filter
        Array(non_quotes) + quotes
      else
        Array(non_quotes.split(",")) + quotes
      end
      # remove any blanks that are left
      value.reject! { |v| v.length.zero? }
      value = value[0] if value.length == 1
      value
    end

    def parse_string_null(filter, value)
      return if value == "null" && filter[:allow_nil]

      value
    end

    def check_deny_empty_filters!(resource, filter, value)
      return unless filter.values[0][:deny_empty]

      if value.nil? || value.empty? || value == "null"
        raise Errors::InvalidFilterValue.new(resource, filter, "(empty)")
      end
    end
  end
end
