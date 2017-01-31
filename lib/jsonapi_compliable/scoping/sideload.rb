module JsonapiCompliable
  class Scoping::Sideload < Scoping::Base
    def apply
      query_hash[:include].empty? ? @scope : super
    end

    def custom_scope
      dsl.sideloads[:custom_scope]
    end

    def apply_standard_scope
      @scope.includes(scrubbed)
    end

    def apply_custom_scope
      custom_scope.call(@scope, scrubbed)
    end

    private

    def scrubbed
      Util::IncludeParams.scrub(query_hash[:include], dsl.allowed_sideloads)
    end
  end
end
