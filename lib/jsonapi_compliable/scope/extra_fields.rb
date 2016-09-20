module JsonapiCompliable
  class Scope::ExtraFields < Scope::Base
    def apply
      each_extra_field do |extra_field|
        @scope = extra_field[:proc].call(@scope)
      end

      @scope
    end

    private

    def each_extra_field
      dsl.extra_fields.each_pair do |namespace, extra_fields|
        extra_fields.each do |extra_field|
          if requested_extra_field?(namespace, extra_field[:name])
            yield extra_field
          end
        end
      end
    end

    def extra_fields
      params[:extra_fields] || {}
    end

    def requested_extra_field?(namespace, field)
      if namespaced = extra_fields[namespace]
        namespaced.include?(field)
      else
        false
      end
    end
  end
end
