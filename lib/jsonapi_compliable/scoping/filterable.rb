module JsonapiCompliable
  # @api private
  module Scoping::Filterable
    # @api private
    def find_filter(name)
      find_filter!(name)
    rescue JsonapiCompliable::Errors::BadFilter
      nil
    end

    # @api private
    def find_filter!(name)
      resource.class.get_attr!(name, :filterable, request: true)
      { name => resource.filters[name] }
    end

    # @api private
    def filter_param
      query_hash[:filter]
    end

    def missing_required_filters
      required_attributes - filter_param.keys
    end

    def required_attributes
      resource.attributes.map do |k, v|
        k if v[:filterable] == :required
      end.compact
    end

    def required_filters_provided?
      missing_required_filters.empty?
    end
  end
end
