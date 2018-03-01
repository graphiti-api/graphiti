module JsonapiCompliable
  # Apply logic when an extra field is requested. Useful for eager loading
  # associations used to compute the extra field.
  #
  # Given a Resource
  #
  #   class PersonResource < ApplicationResource
  #     extra_field :net_worth do |scope|
  #       scope.includes(:assets)
  #     end
  #   end
  #
  # And a corresponding serializer:
  #
  #   class SerializablePerson < JSONAPI::Serializable::Resource
  #     extra_attribute :net_worth do
  #       @object.assets.sum(&:value)
  #     end
  #   end
  #
  # When the user requests the extra field 'net_worth':
  #
  #   GET /people?extra_fields[people]=net_worth
  #
  # The +assets+ will be eager loaded and the 'net_worth' attribute
  # will be present in the response. If this field is not explicitly
  # requested, none of this logic fires.
  #
  # @see Resource.extra_field
  # @see Extensions::ExtraAttribute
  class Scoping::ExtraFields < Scoping::Base
    # Loop through all requested extra fields. If custom scoping
    # logic is define for that field, run it. Otherwise, do nothing.
    #
    # @return the scope object we are chaining/modofying
    def apply
      each_extra_field do |callable|
        @scope = callable.call(@scope, resource.context)
      end

      @scope
    end

    private

    def each_extra_field
      resource.extra_fields.each_pair do |name, callable|
        if extra_fields.include?(name)
          yield callable
        end
      end
    end

    def extra_fields
      query_hash[:extra_fields][resource.type] || []
    end
  end
end
