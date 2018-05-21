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
      filter_name, filter_value = \
        resource.filters.find { |_name, opts| opts[:aliases].include?(name.to_sym) }
      raise JsonapiCompliable::Errors::BadFilter unless filter_name
      if guard = filter_value[:if]
        raise JsonapiCompliable::Errors::BadFilter if resource.context.send(guard) == false
      end
      { filter_name => filter_value }
    end

    # @api private
    def filter_param
      query_hash[:filter]
    end

    def missing_required_filters
      required_filters.keys - filter_param.keys
    end

    def required_filters
      resource.filters.select do |_name, opts|
        opts[:required].respond_to?(:call) ? opts[:required].call(resource.context) : opts[:required]
      end
    end

    def required_filters_provided?
      missing_required_filters.empty?
    end
  end
end
