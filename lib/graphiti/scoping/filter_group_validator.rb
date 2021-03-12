module Graphiti
  class Scoping::FilterGroupValidator
    VALID_FILTER_GROUP_REQUIRED_VALUES = %i[all any]

    def initialize(resource, query_hash)
      @resource = resource
      @query_hash = query_hash
    end

    def raise_unless_filter_group_requirements_met?
      return if grouped_filters.empty?

      case filter_group_requirement
      when :all
        raise_unless_all_requirements_met?
      when :any
        raise_unless_any_requirements_met?
      else
        raise Errors::FilterGroupInvalidRequirement.new(
          resource,
          VALID_FILTER_GROUP_REQUIRED_VALUES
        )
      end
    end

    private

    attr_reader :resource, :query_hash

    def raise_unless_all_requirements_met?
      met = filter_group_names.all? do |filter_name|
        filter_group_filter_param.include?(filter_name)
      end

      unless met
        raise Errors::FilterGroupMissingRequiredFilters.new(
          resource,
          filter_group_names,
          filter_group_requirement
        )
      end
    end

    def raise_unless_any_requirements_met?
      met = filter_group_names.any? do |filter_name|
        filter_group_filter_param.keys.include?(filter_name)
      end

      unless met
        raise Errors::FilterGroupMissingRequiredFilters.new(
          resource,
          filter_group_names,
          filter_group_requirement
        )
      end
    end

    def filter_group_requirement_valid?
      VALID_FILTER_GROUP_REQUIRED_VALUES.include?(filter_group_requirement)
    end

    def filter_group_names
      grouped_filters.fetch(:names, [])
    end

    def filter_group_requirement
      grouped_filters.fetch(:required, :invalid)
    end

    def grouped_filters
      resource.grouped_filters
    end

    def filter_group_filter_param
      query_hash.fetch(:filter, {})
    end
  end
end
