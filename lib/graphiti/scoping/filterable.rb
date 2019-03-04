module Graphiti
  # @api private
  module Scoping::Filterable
    # @api private
    def find_filter(name)
      find_filter!(name)
    rescue Graphiti::Errors::AttributeError
      nil
    end

    # @api private
    def find_filter!(name)
      resource.class.get_attr!(name, :filterable, request: true)
      {name => resource.filters[name]}
    end

    # @api private
    def filter_param
      query_hash[:filter] || {}
    end

    def missing_required_filters
      required_filters - filter_param.keys
    end

    def required_filters
      resource.filters.map { |k, v|
        k if v[:required]
      }.compact
    end

    def missing_dependent_filters
      [].tap do |arr|
        filter_param.each_pair do |key, value|
          if (df = dependent_filters[key])
            missing = df[:dependencies] - filter_param.keys
            unless missing.length.zero?
              arr << {filter: df, missing: missing}
            end
          end
        end
      end
    end

    def dependent_filters
      resource.filters.select do |k, v|
        v[:dependencies].present?
      end
    end
  end
end
