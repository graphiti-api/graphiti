module JSONAPICompliable
  class Scope::Sideload < Scope::Base
    def apply
      params[:include] ? super : @scope
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
      Util::IncludeParams.scrub(controller)
    end
  end
end
