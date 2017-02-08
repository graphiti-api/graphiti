module JsonapiCompliable
  class Scoping::ExtraFields < Scoping::Base
    def apply
      each_extra_field do |callable|
        @scope = callable.call(@scope)
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
