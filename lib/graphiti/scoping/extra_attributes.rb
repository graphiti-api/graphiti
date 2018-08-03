module Graphiti
  class Scoping::ExtraAttributes < Scoping::Base
    # Loop through all requested extra fields. If custom scoping
    # logic is define for that field, run it. Otherwise, do nothing.
    #
    # @return the scope object we are chaining/modofying
    def apply
      each_extra_attribute do |callable|
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
