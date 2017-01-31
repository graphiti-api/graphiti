module JsonapiCompliable
  class Scoping::Sideload < Scoping::Base
    def apply
      query_hash[:include].empty? ? @scope : super
    end

    def custom_scope
      resource.sideloads[:custom_scope]
    end

    def apply_standard_scope
      resource.adapter.sideload(@scope, scrubbed)
    end

    def apply_custom_scope
      custom_scope.call(@scope, scrubbed)
    end

    private

    def scrubbed
      Util::IncludeParams.scrub(query_hash[:include], resource.allowed_sideloads)
    end
  end
end
